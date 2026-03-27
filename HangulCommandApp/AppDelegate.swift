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

        // Setup menu bar
        setupMainMenu()

        // Normal launch - show window
        windowController = MainWindowController(viewController: MainViewController())
        windowController.showAndActivate()

        logger.notice("applicationDidFinishLaunching done")
    }

    // MARK: - Menu Bar

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Hangul Key Changer", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Hangul Key Changer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 8

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
        ]

        let linkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .paragraphStyle: paragraphStyle,
        ]

        credits.append(NSAttributedString(string: "저는 여전히 3벌식을 사랑합니다.\n\n", attributes: normalAttrs))

        let website = NSMutableAttributedString(string: "Website", attributes: linkAttrs)
        website.addAttribute(.link, value: "https://hkc.hulryung.com", range: NSRange(location: 0, length: website.length))

        let github = NSMutableAttributedString(string: "GitHub", attributes: linkAttrs)
        github.addAttribute(.link, value: "https://github.com/hulryung/HangulKeyChanger", range: NSRange(location: 0, length: github.length))

        let x = NSMutableAttributedString(string: "X (Twitter)", attributes: linkAttrs)
        x.addAttribute(.link, value: "https://x.com/hulryung", range: NSRange(location: 0, length: x.length))

        let separator = NSAttributedString(string: "  ·  ", attributes: normalAttrs)

        credits.append(website)
        credits.append(separator)
        credits.append(github)
        credits.append(separator)
        credits.append(x)

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
        ])
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
