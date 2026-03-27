import Cocoa
import os

private let logger = Logger(subsystem: "com.hangulcommand.app", category: "AppDelegate")

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var windowController: MainWindowController!

    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.notice("applicationDidFinishLaunching started")

        windowController = MainWindowController(viewController: MainViewController())
        windowController.showAndActivate()

        logger.notice("applicationDidFinishLaunching done")
    }

    // MARK: - App Lifecycle

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController.showAndActivate()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        logger.notice("applicationWillTerminate")
    }
}
