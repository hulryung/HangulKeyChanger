import SwiftUI

@main
struct HangulCommandAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(KeyMappingManager.shared)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("한영 전환", systemImage: "keyboard") {
            Button("열기") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.center()
                }
            }

            Divider()

            Button(KeyMappingManager.shared.isMappingEnabled ? "비활성화" : "활성화") {
                Task {
                    if KeyMappingManager.shared.isMappingEnabled {
                        await KeyMappingManager.shared.disableMapping()
                    } else {
                        await KeyMappingManager.shared.enableMapping()
                    }
                }
            }

            Divider()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
        }
        .environmentObject(KeyMappingManager.shared)
    }
}