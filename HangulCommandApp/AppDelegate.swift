import Cocoa
import Combine
import os

private let logger = Logger(subsystem: "com.hangulcommand.app", category: "AppDelegate")

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem!
    private(set) var windowController: MainWindowController!
    private var cancellable: AnyCancellable?
    private var statusMenuItem: NSMenuItem!

    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.notice("applicationDidFinishLaunching started")
        NSApp.setActivationPolicy(.accessory)

        windowController = MainWindowController(viewController: MainViewController())
        setupStatusItem()

        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        logger.notice("isLoginLaunch=\(isLoginLaunch)")

        if isLoginLaunch {
            logger.notice("Hiding main window (login item launch)")
        } else {
            logger.notice("Manual launch - showing main window")
            windowController.showAndActivate()
        }

        logger.notice("applicationDidFinishLaunching done")
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Hangul Key Changer")

        let menu = NSMenu()
        statusMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false

        menu.addItem(.separator())
        menu.addItem(withTitle: "열기", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        logger.notice("setupStatusItem done")

        let manager = KeyMappingManager.shared
        updateStatusTitle(enabled: manager.isMappingEnabled)
        cancellable = manager.$isMappingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.updateStatusTitle(enabled: enabled)
            }
    }

    private func updateStatusTitle(enabled: Bool) {
        statusMenuItem.title = enabled ? "활성화됨" : "비활성화됨"
    }

    // MARK: - App Lifecycle

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.notice("applicationShouldHandleReopen, hasVisibleWindows=\(flag)")
        if !flag {
            showMainWindow()
        }
        return true
    }

    @objc func showMainWindow() {
        logger.notice("showMainWindow called")
        windowController.showAndActivate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        logger.notice("applicationWillTerminate")
    }
}
