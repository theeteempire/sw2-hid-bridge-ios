import SwiftUI

struct ShortcutsView: View {
    @EnvironmentObject var bridge: TCPBridge
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("أزرار جاهزة — قابلة للتعديل")) {
                    ForEach($settings.shortcuts) { $shortcut in
                        NavigationLink(destination: ShortcutEditor(shortcut: $shortcut)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shortcut.title).font(.headline)
                                Text(shortcut.text.replacingOccurrences(of: "\n", with: " ↵ "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        settings.shortcuts.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        settings.shortcuts.move(fromOffsets: from, toOffset: to)
                    }
                }

                Section {
                    Button("إضافة اختصار") {
                        settings.shortcuts.append(Shortcut(title: "اختصار جديد", text: ""))
                    }
                    Button("استعادة الافتراضي") {
                        settings.shortcuts = Shortcut.defaults
                    }
                }
            }
            .navigationTitle("الاختصارات")
            .toolbar { EditButton() }
        }
    }
}

struct ShortcutEditor: View {
    @Binding var shortcut: Shortcut
    @EnvironmentObject var bridge: TCPBridge
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section(header: Text("الاسم")) {
                TextField("اسم الزر", text: $shortcut.title)
            }
            Section(header: Text("النص المرسل")) {
                TextEditor(text: $shortcut.text)
                    .frame(minHeight: 180)
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                Button(action: {
                    bridge.sendText(shortcut.text, timing: settings.timing, report: settings.report)
                }) {
                    Label("إرسال هذا الاختصار", systemImage: "paperplane.fill")
                }
                .disabled(shortcut.text.isEmpty || !bridge.connected)
            }
            Section(header: Text("نص الاختصارات الافتراضية")) {
                Text("LOAD \"TXT:NS2\"\nRUN\nREMOVE NSR,&H60000000,&H3FFFFFFF\nV=START(39380,192,168,31,24)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(shortcut.title)
    }
}
