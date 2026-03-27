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

        let manager = KeyMappingManager.shared

        // Apply hidutil mapping if enabled (important for login launch)
        if UserDefaults.standard.bool(forKey: "mappingEnabled") {
            manager.applyHidutil()
        }

        // Detect login item launch
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        if isLoginLaunch {
            logger.notice("Login launch - mapping applied, quitting silently")
            NSApp.setActivationPolicy(.prohibited)
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }

        // Normal launch - show window
        windowController = MainWindowController(viewController: MainViewController())
        windowController.showAndActivate()

        logger.notice("applicationDidFinishLaunching done")
    }

    // MARK: - App Lifecycle

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showAndActivate()
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
