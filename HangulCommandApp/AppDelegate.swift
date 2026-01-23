import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Hangul Toggle")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc func togglePopover() {
        // Activate app and show main window
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
    }
}