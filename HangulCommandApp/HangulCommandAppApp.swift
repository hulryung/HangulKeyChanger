import SwiftUI

@main
struct HangulCommandAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("한영 전환 앱", id: "main") {
            ContentView()
                .environmentObject(KeyMappingManager.shared)
        }
        .windowResizability(.contentSize)
    }
}
