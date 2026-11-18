import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bridge: TCPBridge
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("الاتصال")) {
                    Toggle("إعادة الاتصال تلقائياً", isOn: $settings.autoConnect)
                    Text("عند انقطاع TCP يعاود التطبيق الاتصال بتأخير متصاعد حتى 30 ثانية.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("التوقيت (ملي ثانية)")) {
                    Picker("ال preset", selection: timingPreset) {
                        ForEach(Timing.presets, id: \.0) { name, _ in Text(name).tag(name) }
                    }
                    .pickerStyle(.segmented)

                    Stepper("charDelay \(settings.timing.charDelay)", value: $settings.timing.charDelay, in: 0...2000, step: 5)
                    Stepper("press \(settings.timing.press)", value: $settings.timing.press, in: 8...500, step: 1)
                    Stepper("lineDelay \(settings.timing.lineDelay)", value: $settings.timing.lineDelay, in: 0...5000, step: 10)
                    Stepper("initialDelay \(settings.timing.initialDelay)", value: $settings.timing.initialDelay, in: 0...10000, step: 50)
                }

                Section(header: Text("التخطيط ونمط HID")) {
                    Picker("التخطيط", selection: $settings.layout) {
                        ForEach(LayoutID.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.layout) { newValue in bridge.applyLayout(newValue) }

                    Picker("الإرسال", selection: $settings.report) {
                        ForEach(ReportMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.report) { newValue in bridge.applyReport(newValue) }
                }

                Section(header: Text("القيود المعروفة")) {
                    Text("iPhone يتصل باللوحة عبر Wi-Fi TCP فقط. منفذ USB Serial واختصار لوحة المفاتيح العامة وشريط القائمة غير متوفرة على iOS.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("DONE يعني أن ESP32 أرسل تقارير HID، وليس دليلاً على أن Switch 2 عرض النص.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
        }
    }

    private var timingPreset: Binding<String> {
        Binding(
            get: {
                for (name, preset) in Timing.presets where preset == settings.timing { return name }
                return "custom"
            },
            set: { name in
                if let found = Timing.presets.first(where: { $0.0 == name }) {
                    settings.timing = found.1
                }
            }
        )
    }
}
