import Foundation
import Network
import SwiftUI

final class TCPBridge: ObservableObject {
    // MARK: - Published state
    @Published private(set) var connected = false
    @Published private(set) var lastError = ""
    @Published private(set) var events: [BridgeEvent] = []
    @Published private(set) var jobState = "—"
    @Published private(set) var jobDetail = ""
    @Published private(set) var jobSent = 0
    @Published private(set) var jobTotal = 0
    @Published private(set) var stats: [String: String] = [:]
    @Published private(set) var discovered: [String] = []

    // MARK: - Wire
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "sw2.hidbridge.tcp")
    private var buffer = Data()

    // MARK: - Job tracking
    private var currentJobID: String?
    private var ackTimer: Timer?
    private var stallTimer: Timer?
    private var lastText: String?
    private var lastSentAt: Date?

    // MARK: - Reconnect
    private var savedHost = BridgeProtocol.defaultHost
    private var savedPort: UInt16 = BridgeProtocol.defaultPort
    private var autoReconnect = true
    private var retryAttempt = 0
    private var retryWork: DispatchWorkItem?

    deinit {
        ackTimer?.invalidate()
        stallTimer?.invalidate()
        retryWork?.cancel()
        browser?.cancel()
        connection?.cancel()
    }

    // MARK: - Connection

    func connect(host: String, port: UInt16, autoReconnect: Bool) {
        disconnect(cancelAuto: true)
        savedHost = host
        savedPort = port
        self.autoReconnect = autoReconnect

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.queue = queue

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.connected = true
                    self.lastError = ""
                    self.retryAttempt = 0
                    self.buffer.removeAll()
                    self.log("متصل بـ \(host):\(port)")
                    self.receive()
                    self.ping()
                    self.queryStatus()
                }
            case .waiting(let error):
                self?.onDisconnected("انتظار: \(error.localizedDescription)")
            case .failed(let error):
                self?.onDisconnected(error.localizedDescription)
            case .cancelled:
                self?.onDisconnected("أُلغي الاتصال")
            default:
                break
            }
        }

        self.connection = connection
        connection.start(queue: queue)
    }

    func disconnect(cancelAuto: Bool = false) {
        if cancelAuto { autoReconnect = false }
        retryWork?.cancel()
        retryWork = nil
        ackTimer?.invalidate()
        stallTimer?.invalidate()
        ackTimer = nil
        stallTimer = nil
        connection?.cancel()
        connection = nil
        connected = false
        currentJobID = nil
        jobState = "—"
        jobDetail = ""
        buffer.removeAll()
    }

    private func onDisconnected(_ reason: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.connection != nil || self.connected else { return }
            self.connected = false
            self.lastError = reason
            self.log("انقطع الاتصال: \(reason)")
            self.connection = nil
            self.ackTimer?.invalidate()
            self.stallTimer?.invalidate()
            self.currentJobID = nil
            if self.jobState != "done" && self.jobState != "error" {
                self.jobState = "unknown"
                self.jobDetail = "انقطع الرابط أثناء الإرسال — لا تُعد الإرسال تلقائياً"
            }
            if self.autoReconnect {
                self.retryAttempt += 1
                let delay = min(30, 2 * self.retryAttempt)
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.connect(host: self.savedHost, port: self.savedPort, autoReconnect: true)
                }
                self.retryWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay), execute: work)
            }
        }
    }

    // MARK: - Discovery

    func startDiscovery() {
        browser?.cancel()
        let browser = NWBrowser(for: .bonjour(type: "_hidbridge._tcp", domain: "local."), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found = results.compactMap { result -> String? in
                guard case .hostPort(let host, let port) = result.endpoint else { return nil }
                return "\(Self.hostString(host)):\(port.rawValue)"
            }
            DispatchQueue.main.async { self?.discovered = Array(Set(found)).sorted() }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        discovered.removeAll()
    }

    private static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _): return name
        case .ipv4(let address): return address.debugDescription
        case .ipv6(let address): return address.debugDescription
        @unknown default: return String(describing: host)
        }
    }

    // MARK: - Sending

    func sendLine(_ line: String) {
        guard let connection, connection.state == .ready else {
            lastError = "غير متصل باللوحة"
            return
        }
        let data = Data((line + "\n").utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                DispatchQueue.main.async { self?.lastError = "إرسال: \(error.localizedDescription)" }
            }
        })
    }

    func sendText(_ text: String, timing: Timing, report: ReportMode) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { lastError = "النص فارغ"; return }
        guard normalized.utf8.count <= BridgeProtocol.maxText else {
            lastError = "النص أكبر من \(BridgeProtocol.maxText) بايت"
            return
        }
        guard normalized.utf8.allSatisfy({ $0 < 128 }) else {
            lastError = "الفيرموير يدعم ASCII فقط ( التخطيط us/gb )"
            return
        }
        guard currentJobID == nil else { lastError = "هناك إرسال قيد التنفيذ"; return }
        if let previous = lastText, previous == normalized,
           let at = lastSentAt, Date().timeIntervalSince(at) < 0.35 {
            lastError = "رُفض إرسال مكرر خلال نافذة الحماية"
            return
        }

        let id = BridgeProtocol.newID()
        currentJobID = id
        lastText = normalized
        lastSentAt = Date()
        jobState = "accepted"
        jobDetail = "تم التحقق محلياً، بانتظار الاستلام"
        jobSent = 0
        jobTotal = normalized.count
        log("إرسال \(normalized.utf8.count) بايت / \(normalized.count) حرف")

        sendLine(BridgeProtocol.buildType(id: id, text: normalized, timing: timing))

        ackTimer?.invalidate()
        ackTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            guard let self, self.currentJobID == id, self.jobState == "accepted" else { return }
            self.jobState = "uncertain"
            self.jobDetail = "انتهت مهلة الاستلام — لا تُعد الإرسال تلقائياً"
            self.log("ACK timeout for \(id)")
        }
        RunLoop.main.add(ackTimer!, forMode: .common)
    }

    func stop() {
        sendLine(BridgeProtocol.buildStop())
        if currentJobID != nil {
            jobState = "stopped"
            jobDetail = "أُرسل أمر الإيقاف"
        }
    }

    func emergencyStop() { stop() }

    func clearCaps() {
        sendLine(BridgeProtocol.buildKey(BridgeProtocol.newID("k"), usage: 57))
        log("إرسال KEY 57 لمسح Caps Lock")
    }

    func ping() { sendLine(BridgeProtocol.buildPing(BridgeProtocol.newID("p"))) }
    func queryStatus() { sendLine(BridgeProtocol.buildStatus(BridgeProtocol.newID("s"))) }
    func queryNet() { sendLine(BridgeProtocol.buildNet(BridgeProtocol.newID("n"))) }
    func setBlock(_ mode: String) {
        sendLine(BridgeProtocol.buildNetBlock(BridgeProtocol.newID("n"), mode))
    }
    func applyLayout(_ layout: LayoutID) {
        sendLine(BridgeProtocol.buildConfig(BridgeProtocol.newID("c"), layout))
    }
    func applyReport(_ mode: ReportMode) {
        sendLine(BridgeProtocol.buildReport(BridgeProtocol.newID("r"), mode))
    }

    // MARK: - Receive / parse

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.buffer.append(data)
                self.drainLines()
            }
            if let error {
                DispatchQueue.main.async { self.onDisconnected("قراءة: \(error.localizedDescription)") }
                return
            }
            if isComplete {
                DispatchQueue.main.async { self.onDisconnected("أغلق الطرف الآخر الاتصال") }
                return
            }
            self.receive()
        }
    }

    private func drainLines() {
        while let index = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: 0..<index)
            buffer.removeSubrange(0...index)
            let line = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                DispatchQueue.main.async { self.handleLine(line) }
            }
        }
    }

    private func handleLine(_ line: String) {
        log(line)
        let tokens = line.split(separator: " ").map(String.init)
        guard let kind = tokens.first else { return }
        let id = tokens.count > 1 ? tokens[1] : "-"

        switch kind {
        case "BOOT":
            stats["fw"] = id

        case "PONG":
            if tokens.count > 2 { stats["fw"] = tokens[2] }
            if tokens.count > 3 { stats["proto"] = tokens[3] }
            if tokens.count > 4 { stats["layout"] = tokens[4] }
            if tokens.count > 5 { stats["caps"] = tokens[5] }

        case "STAT", "NET":
            stats.merge(Self.fields(tokens.dropFirst(2))) { _, new in new }

        case "CONFIG":
            if tokens.count > 2 { stats["config"] = tokens[2] }

        case "KEY":
            if tokens.count > 2 { stats["key"] = tokens[2] }

        case "REPORT":
            if tokens.count > 2 { stats["report"] = tokens[2] }

        case "ACK":
            guard id == currentJobID else { return }
            jobState = "received"
            jobDetail = tokens.count > 2 ? "استلم اللوحة النص (\(tokens[2]))" : "استلم اللوحة النص"
            ackTimer?.invalidate()
            stallTimer?.invalidate()
            stallTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
                guard let self, self.currentJobID == id else { return }
                self.jobState = "uncertain"
                self.jobDetail = "توقف أثناء الكتابة — لا تُعد الإرسال تلقائياً"
            }
            RunLoop.main.add(stallTimer!, forMode: .common)

        case "PROG":
            guard id == currentJobID else { return }
            jobState = "typing"
            jobSent = Int(tokens[safe: 2] ?? "0") ?? 0
            jobTotal = Int(tokens[safe: 3] ?? "0") ?? jobTotal
            jobDetail = "جارٍ الكتابة \(jobSent)/\(jobTotal)"

        case "DONE":
            guard id == currentJobID else { return }
            jobState = "done"
            let typed = Int(tokens[safe: 2] ?? "0") ?? 0
            let total = Int(tokens[safe: 3] ?? "0") ?? jobTotal
            let ms = Int(tokens[safe: 4] ?? "0") ?? 0
            let reason = tokens[safe: 5] ?? "unknown"
            jobSent = typed
            jobTotal = total
            jobDetail = "انتهى: \(typed)/\(total) خلال \(ms) ms — \(reason)"
            clearJobTimers()
            currentJobID = nil
            queryStatus()

        case "ERR":
            let code = tokens[safe: 2] ?? "E_UNKNOWN"
            let message = tokens.dropFirst(3).joined(separator: " ")
            if id == currentJobID {
                jobState = "error"
                jobDetail = "\(code): \(message)"
                clearJobTimers()
                currentJobID = nil
            } else {
                lastError = "\(code): \(message)"
            }

        default:
            break
        }
    }

    private func clearJobTimers() {
        ackTimer?.invalidate()
        stallTimer?.invalidate()
        ackTimer = nil
        stallTimer = nil
    }

    private static func fields(_ tokens: ArraySlice<String>) -> [String: String] {
        var result: [String: String] = [:]
        for token in tokens {
            let parts = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
        return result
    }

    private func log(_ text: String) {
        events.append(BridgeEvent(kind: "LOG", text: text))
        if events.count > 300 { events.removeFirst(events.count - 300) }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
