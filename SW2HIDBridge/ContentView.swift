import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ConnectionView()
                .tabItem { Label("الاتصال", systemImage: "network") }
            TypingView()
                .tabItem { Label("الكتابة", systemImage: "keyboard") }
            ShortcutsView()
                .tabItem { Label("الاختصارات", systemImage: "bolt.fill") }
            NetworkView()
                .tabItem { Label("الشبكة", systemImage: "wifi") }
            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape") }
        }
        .accentColor(.green)
    }
}
