import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bridge: TCPBridge
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("اللوحة ESP32-S3")) {
                    HStack {
                        TextField("المضيف", text: $settings.host)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        TextField("المنفذ", text: $settings.port)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                    Button(action: {
                        let port = UInt16(settings.port) ?? BridgeProtocol.defaultPort
                        bridge.connect(host: settings.host, port: port, autoReconnect: settings.autoConnect)
                    }) {
                        Label(bridge.connected ? "إعادة الاتصال" : "اتصال", systemImage: "plug")
                    }
                    Button(role: .destructive) {
                        bridge.disconnect(cancelAuto: true)
                    } label: {
                        Label("قطع الاتصال", systemImage: "plug.slash")
                    }
                    .disabled(!bridge.connected)
                }

                Section(header: Text("اكتشاف Bonjour")) {
                    Button("بحث عن _hidbridge._tcp") { bridge.startDiscovery() }
                    Button("إيقاف البحث") { bridge.stopDiscovery() }
                    ForEach(bridge.discovered, id: \.self) { item in
                        Button(item) {
                            let parts = item.split(separator: ":")
                            if parts.count == 2 {
                                settings.host = String(parts[0])
                                settings.port = String(parts[1])
                            }
                        }
                    }
                }

                Section(header: Text("الحالة")) {
                    StatusRow(title: "الاتصال", value: bridge.connected ? "متصل" : "غير متصل")
                    StatusRow(title: "الفيرموير", value: bridge.stats["fw"] ?? "—")
                    StatusRow(title: "البروتوكول", value: bridge.stats["proto"] ?? "—")
                    StatusRow(title: "التخطيط", value: bridge.stats["layout"] ?? "—")
                    StatusRow(title: "القدرات", value: bridge.stats["caps"] ?? "—")
                    StatusRow(title: "USB", value: bridge.stats["usb"] ?? "—")
                    StatusRow(title: "LEDs", value: bridge.stats["leds"] ?? "—")
                    StatusRow(title: "نمط الإرسال", value: bridge.stats["report"] ?? "—")
                    StatusRow(title: "حالة المهمة", value: bridge.jobState)
                    StatusRow(title: "تفاصيل", value: bridge.jobDetail)
                    if !bridge.lastError.isEmpty {
                        StatusRow(title: "آخر خطأ", value: bridge.lastError)
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("السجل")) {
                    ForEach(bridge.events.suffix(60)) { event in
                        Text(event.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("SW2 HID Bridge")
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
