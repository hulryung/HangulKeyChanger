import Cocoa
import Combine
import os

private let logger = Logger(subsystem: "com.hangulcommand.app", category: "AppDelegate")

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.notice("applicationDidFinishLaunching started")
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        // Override close button to hide instead of destroy
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }),
               let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.target = self
                closeButton.action = #selector(self.hideMainWindow)
                logger.notice("Close button overridden")
            }
        }

        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        let showIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true

        logger.notice("isLoginLaunch=\(isLoginLaunch), showMenuBarIcon=\(showIcon)")

        if isLoginLaunch {
            logger.notice("Hiding main window (login item launch)")
            DispatchQueue.main.async {
                for window in NSApp.windows where window.canBecomeMain {
                    window.orderOut(nil)
                }
            }
        } else {
            logger.notice("Manual launch - showing main window")
        }

        logger.notice("applicationDidFinishLaunching done")
    }

    @objc func hideMainWindow() {
        logger.notice("hideMainWindow called")
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.orderOut(nil)
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "한영 전환")

        let menu = NSMenu()
        let statusMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false

        menu.addItem(.separator())
        menu.addItem(withTitle: "열기", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu

        let showIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        statusItem.isVisible = showIcon
        logger.notice("setupStatusItem done, isVisible=\(showIcon)")

        let manager = KeyMappingManager.shared
        updateStatusTitle(statusMenuItem, enabled: manager.isMappingEnabled)
        cancellable = manager.$isMappingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.updateStatusTitle(statusMenuItem, enabled: enabled)
            }
    }

    private func updateStatusTitle(_ item: NSMenuItem, enabled: Bool) {
        item.title = enabled ? "활성화됨" : "비활성화됨"
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
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        logger.notice("applicationWillTerminate")
    }
}
