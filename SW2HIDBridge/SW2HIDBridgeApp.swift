import SwiftUI

@main
struct SW2HIDBridgeApp: App {
    @StateObject private var bridge = TCPBridge()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
                .environmentObject(settings)
        }
    }
}
