import SwiftUI

struct NetworkView: View {
    @EnvironmentObject var bridge: TCPBridge

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("نقطة وصول الكونسول SWITCH2")) {
                    Text("اللوحة تنشر SWITCH2 / 12345678 على 192.168.4.1. منفذ TCP 8231 يحمل نفس أوامر HID. اختر وضع الحجب ثم راجع النتيجة عبر NET.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("وضع الحجب")) {
                    Button("SAFE — NET block on") { bridge.setBlock("on") }
                    Button("NINTENDO — NET block nintendo") { bridge.setBlock("nintendo") }
                    Button("ONLINE — NET block off") { bridge.setBlock("off") }
                    Button("استعلام NET") { bridge.queryNet() }
                }

                Section(header: Text("حالة الشبكة من اللوحة")) {
                    StatusRow(title: "AP", value: bridge.stats["ap"] ?? "—")
                    StatusRow(title: "IP", value: bridge.stats["ip"] ?? "—")
                    StatusRow(title: "clients", value: bridge.stats["clients"] ?? "—")
                    StatusRow(title: "block", value: bridge.stats["block"] ?? "—")
                    StatusRow(title: "napt", value: bridge.stats["napt"] ?? "—")
                    StatusRow(title: "sta", value: bridge.stats["sta"] ?? "—")
                    StatusRow(title: "blocked", value: bridge.stats["blocked"] ?? "—")
                    StatusRow(title: "fwd", value: bridge.stats["fwd"] ?? "—")
                }
            }
            .navigationTitle("الشبكة")
        }
    }
}
