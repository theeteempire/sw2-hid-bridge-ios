import Foundation

struct Timing: Codable, Hashable {
    var charDelay: Int = 55
    var press: Int = 35
    var lineDelay: Int = 180
    var initialDelay: Int = 1200

    static let slow = Timing(charDelay: 90, press: 50, lineDelay: 260, initialDelay: 1500)
    static let normal = Timing()
    static let fast = Timing(charDelay: 25, press: 20, lineDelay: 100, initialDelay: 900)

    static let presets: [(String, Timing)] = [
        ("slow", .slow), ("normal", .normal), ("fast", .fast)
    ]
}

enum LayoutID: String, Codable, CaseIterable, Identifiable {
    case us, gb
    var id: String { rawValue }
}

enum ReportMode: String, Codable, CaseIterable, Identifiable {
    case single, split
    var id: String { rawValue }
}

enum BridgeProtocol {
    static let maxText = 4096
    static let defaultHost = "192.168.4.1"
    static let defaultPort: UInt16 = 8231

    static func newID(_ prefix: String = "j") -> String {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return prefix + String(raw.prefix(10))
    }

    static func buildType(id: String, text: String, timing: Timing) -> String {
        let b64 = Data(text.utf8).base64EncodedString()
        return "TYPE \(id) \(timing.charDelay) \(timing.press) \(timing.lineDelay) \(timing.initialDelay) \(b64)"
    }

    static func buildPing(_ id: String) -> String { "PING \(id)" }
    static func buildStatus(_ id: String) -> String { "STATUS \(id)" }
    static func buildConfig(_ id: String, _ layout: LayoutID) -> String { "CONFIG \(id) \(layout.rawValue)" }
    static func buildKey(_ id: String, usage: Int, mods: Int = 0) -> String { "KEY \(id) \(usage) \(mods)" }
    static func buildReport(_ id: String, _ mode: ReportMode) -> String { "REPORT \(id) \(mode.rawValue)" }
    static func buildStop(_ id: String = "*") -> String { "STOP \(id)" }
    static func buildNet(_ id: String) -> String { "NET \(id)" }
    static func buildNetBlock(_ id: String, _ mode: String) -> String { "NET \(id) block \(mode)" }

    static func estimateSeconds(_ text: String, _ timing: Timing, _ report: ReportMode) -> Double {
        let chars = text.count
        let newlines = text.filter { $0 == "\n" }.count
        let press = max(8, timing.press)
        let lead = max(4, press / 4)
        let gap = max(4, press / 8)
        let perChar = report == .split
            ? (lead + press + 2 * gap + max(0, timing.charDelay))
            : (press + gap + max(0, timing.charDelay))
        return (Double(timing.initialDelay)
            + Double(chars) * Double(perChar)
            + Double(newlines) * Double(max(0, timing.lineDelay))) / 1000.0
    }
}

struct BridgeEvent: Identifiable {
    let id = UUID()
    let kind: String
    let text: String
    let date = Date()
}
