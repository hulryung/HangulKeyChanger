import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("시작시 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Toggle("메뉴바 아이콘 표시", isOn: $showMenuBarIcon)
                .onChange(of: showMenuBarIcon) { _, newValue in
                    guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
                    appDelegate.statusItem.isVisible = newValue
                    // When hiding menu bar icon, show main window as safety net
                    if !newValue {
                        appDelegate.showMainWindow()
                    }
                }
        }
        .font(.subheadline)
    }
}
