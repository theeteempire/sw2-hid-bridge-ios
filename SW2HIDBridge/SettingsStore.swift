import Foundation
import Combine

struct Shortcut: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var text: String

    static let defaults: [Shortcut] = [
        Shortcut(
            title: "LOAD \"TXT:NS2\"",
            text: "LOAD \"TXT:NS2\""
        ),
        Shortcut(
            title: "RUN + REMOVE + START",
            text: "RUN\nREMOVE NSR,&H60000000,&H3FFFFFFF\nV=START(39380,192,168,31,24)"
        ),
        Shortcut(
            title: "كامل kaiHEN (4 أسطر)",
            text: "LOAD \"TXT:NS2\"\nRUN\nREMOVE NSR,&H60000000,&H3FFFFFFF\nV=START(39380,192,168,31,24)"
        )
    ]
}

final class SettingsStore: ObservableObject {
    @Published var host: String {
        didSet { save() }
    }
    @Published var port: String {
        didSet { save() }
    }
    @Published var autoConnect: Bool {
        didSet { save() }
    }
    @Published var timing: Timing {
        didSet { save() }
    }
    @Published var layout: LayoutID {
        didSet { save() }
    }
    @Published var report: ReportMode {
        didSet { save() }
    }
    @Published var shortcuts: [Shortcut] {
        didSet { save() }
    }

    private let store = UserDefaults.standard

    init() {
        host = (Store.string("host")) ?? BridgeProtocol.defaultHost
        port = (Store.string("port")) ?? String(BridgeProtocol.defaultPort)
        autoConnect = Store.bool("autoConnect", fallback: true)
        timing = Store.decodable("timing", default: .normal)
        layout = Store.decodable("layout", default: .us)
        report = Store.decodable("report", default: .single)
        shortcuts = Store.decodable("shortcuts", default: Shortcut.defaults)
    }

    private func save() {
        Store.set(host, for: "host")
        Store.set(port, for: "port")
        Store.set(autoConnect, for: "autoConnect")
        Store.set(timing, for: "timing")
        Store.set(layout, for: "layout")
        Store.set(report, for: "report")
        Store.set(shortcuts, for: "shortcuts")
    }

    private enum Store {
        static func string(_ key: String) -> String? {
            UserDefaults.standard.string(forKey: "sw2." + key)
        }
        static func bool(_ key: String, fallback: Bool) -> Bool {
            let v = UserDefaults.standard.object(forKey: "sw2." + key) as? Bool
            return v ?? fallback
        }
        static func decodable<T: Decodable>(_ key: String, default: T) -> T {
            guard let data = UserDefaults.standard.data(forKey: "sw2." + key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else { return `default` }
            return value
        }
        static func set(_ value: Bool, for key: String) {
            UserDefaults.standard.set(value, forKey: "sw2." + key)
        }
        static func set(_ value: String, for key: String) {
            UserDefaults.standard.set(value, forKey: "sw2." + key)
        }
        static func set<T: Encodable>(_ value: T, for key: String) {
            guard let data = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(data, forKey: "sw2." + key)
        }
    }
}
