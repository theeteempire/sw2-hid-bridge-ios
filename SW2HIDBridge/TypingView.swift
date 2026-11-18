import SwiftUI
import UIKit

struct TypingView: View {
    @EnvironmentObject var bridge: TCPBridge
    @EnvironmentObject var settings: SettingsStore
    @State private var text = ""

    private var estimated: String {
        String(format: "%.1f ث", BridgeProtocol.estimateSeconds(text, settings.timing, settings.report))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("النص")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Button("لصق من الحافظة") {
                            if let value = UIPasteboard.general.string { text = value }
                        }
                        Button("مسح") { text = "" }
                    }
                }

                Section(header: Text("الإرسال")) {
                    Button(action: {
                        bridge.sendText(text, timing: settings.timing, report: settings.report)
                    }) {
                        Label("TYPE — أرسل إلى Switch 2", systemImage: "paperplane.fill")
                    }
                    .disabled(text.isEmpty || !bridge.connected)

                    HStack {
                        Button("STOP") { bridge.stop() }
                        Button("إيقاف طارئ") { bridge.emergencyStop() }
                            .foregroundColor(.red)
                    }
                    Button("مسح Caps Lock (KEY 57)") { bridge.clearCaps() }
                }

                Section(header: Text("الفحص")) {
                    Button("PING") { bridge.ping() }
                    Button("STATUS") { bridge.queryStatus() }
                }

                Section(header: Text("معاينة")) {
                    StatusRow(title: "الأحرف", value: "\(text.count)")
                    StatusRow(title: "البايتات", value: "\(text.utf8.count)")
                    StatusRow(title: "المدة التقديرية", value: estimated)
                    StatusRow(title: "الحد الأقصى", value: "\(BridgeProtocol.maxText) بايت")
                }

                Section(header: Text("الحالة")) {
                    StatusRow(title: "المهمة", value: bridge.jobState)
                    StatusRow(title: "التقدم", value: "\(bridge.jobSent)/\(bridge.jobTotal)")
                    StatusRow(title: "التفاصيل", value: bridge.jobDetail)
                }
            }
            .navigationTitle("الكتابة")
        }
    }
}
