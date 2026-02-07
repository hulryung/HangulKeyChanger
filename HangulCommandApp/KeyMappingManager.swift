import SwiftUI
import Foundation

// MARK: - Key Info

struct KeyInfo: Equatable {
    let hidUsageCode: UInt32
    let displayName: String

    static let defaultKey = KeyInfo(hidUsageCode: 0xE7, displayName: "Right Command ⌘")

    var fullHIDHex: String {
        String(format: "0x7%08x", hidUsageCode)
    }
}

// MARK: - Key Code Converter

struct KeyCodeConverter {
    // macOS virtual keycode → HID usage code (USB HID spec)
    private static let virtualToHID: [UInt16: UInt32] = [
        // Modifier keys
        0x36: 0xE7, 0x37: 0xE3,  // Right/Left Command
        0x38: 0xE1, 0x3C: 0xE5,  // Left/Right Shift
        0x3A: 0xE2, 0x3D: 0xE6,  // Left/Right Option
        0x3B: 0xE0, 0x3E: 0xE4,  // Left/Right Control
        0x39: 0x39,               // Caps Lock
        // Letters
        0x00: 0x04, 0x0B: 0x05, 0x08: 0x06, 0x02: 0x07,
        0x0E: 0x08, 0x03: 0x09, 0x05: 0x0A, 0x04: 0x0B,
        0x22: 0x0C, 0x26: 0x0D, 0x28: 0x0E, 0x25: 0x0F,
        0x2E: 0x10, 0x2D: 0x11, 0x1F: 0x12, 0x23: 0x13,
        0x0C: 0x14, 0x0F: 0x15, 0x01: 0x16, 0x11: 0x17,
        0x20: 0x18, 0x09: 0x19, 0x0D: 0x1A, 0x07: 0x1B,
        0x10: 0x1C, 0x06: 0x1D,
        // Numbers
        0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21,
        0x17: 0x22, 0x16: 0x23, 0x1A: 0x24, 0x1C: 0x25,
        0x19: 0x26, 0x1D: 0x27,
        // Function keys
        0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D,
        0x60: 0x3E, 0x61: 0x3F, 0x62: 0x40, 0x64: 0x41,
        0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45,
        // Special
        0x24: 0x28, 0x30: 0x2B, 0x31: 0x2C,
        0x33: 0x2A, 0x35: 0x29, 0x75: 0x4C,
    ]

    private static let keyNames: [UInt16: String] = [
        0x36: "Right Command ⌘", 0x37: "Left Command ⌘",
        0x38: "Left Shift ⇧", 0x3C: "Right Shift ⇧",
        0x3A: "Left Option ⌥", 0x3D: "Right Option ⌥",
        0x3B: "Left Control ⌃", 0x3E: "Right Control ⌃",
        0x39: "Caps Lock ⇪",
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D",
        0x0E: "E", 0x03: "F", 0x05: "G", 0x04: "H",
        0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P",
        0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
        0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8",
        0x19: "9", 0x1D: "0",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x24: "Return ↩", 0x30: "Tab ⇥", 0x31: "Space",
        0x33: "Delete ⌫", 0x35: "Escape ⎋", 0x75: "Forward Delete ⌦",
    ]

    static func convert(virtualKeyCode: UInt16) -> KeyInfo? {
        guard let hid = virtualToHID[virtualKeyCode],
              let name = keyNames[virtualKeyCode] else { return nil }
        return KeyInfo(hidUsageCode: hid, displayName: name)
    }

    static func extractKeyInfo(from event: NSEvent) -> KeyInfo? {
        let keyCode = event.keyCode
        if event.type == .flagsChanged {
            let isDown: Bool
            switch keyCode {
            case 0x36, 0x37: isDown = event.modifierFlags.contains(.command)
            case 0x38, 0x3C: isDown = event.modifierFlags.contains(.shift)
            case 0x3A, 0x3D: isDown = event.modifierFlags.contains(.option)
            case 0x3B, 0x3E: isDown = event.modifierFlags.contains(.control)
            case 0x39: isDown = event.modifierFlags.contains(.capsLock)
            default: isDown = true
            }
            return isDown ? convert(virtualKeyCode: keyCode) : nil
        } else if event.type == .keyDown {
            return convert(virtualKeyCode: keyCode)
        }
        return nil
    }
}

// MARK: - Errors

enum KeyMappingError: LocalizedError {
    case directoryNotWritable
    case processFailed(Int32)
    case appleScriptExecutionFailed
    case permissionDenied
    case pathValidationFailed
    case launchAgentNotFound

    var errorDescription: String? {
        switch self {
        case .directoryNotWritable:
            return "디렉터리에 쓰기 권한이 없습니다."
        case .processFailed(let code):
            return "프로세스 실행 실패 (종료 코드: \(code))"
        case .appleScriptExecutionFailed:
            return "AppleScript 실행에 실패했습니다."
        case .permissionDenied:
            return "권한이 거부되었습니다."
        case .pathValidationFailed:
            return "경로 유효성 검사에 실패했습니다."
        case .launchAgentNotFound:
            return "LaunchAgent를 찾을 수 없습니다."
        }
    }
}

// MARK: - Key Mapping Manager

@MainActor
class KeyMappingManager: ObservableObject {
    static let shared = KeyMappingManager()

    @Published var isMappingEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sourceKeyInfo: KeyInfo
    @Published var capturedKeyInfo: KeyInfo?

    private var keyMonitor: Any?
    private let launchAgentLabel = "com.hangulcommand.userkeymapping"

    private var launchAgentPlistPath: String {
        "/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    private var scriptPath: String {
        getSecureScriptPath()
    }

    private init() {
        sourceKeyInfo = Self.loadSourceKey()
        Task { await checkCurrentStatus() }
    }

    // MARK: - Source Key Persistence

    nonisolated private static func loadSourceKey() -> KeyInfo {
        guard let hid = UserDefaults.standard.object(forKey: "sourceHIDUsageCode") as? Int,
              let name = UserDefaults.standard.string(forKey: "sourceKeyDisplayName") else {
            return .defaultKey
        }
        return KeyInfo(hidUsageCode: UInt32(hid), displayName: name)
    }

    func setSourceKey(_ keyInfo: KeyInfo) {
        sourceKeyInfo = keyInfo
        UserDefaults.standard.set(Int(keyInfo.hidUsageCode), forKey: "sourceHIDUsageCode")
        UserDefaults.standard.set(keyInfo.displayName, forKey: "sourceKeyDisplayName")

        if isMappingEnabled {
            Task { _ = await enableMapping() }
        }
    }

    // MARK: - Key Capture

    func startKeyCapture() {
        capturedKeyInfo = nil

        // Temporarily clear hidutil mapping so we detect physical keys
        _ = try? executeProcess("/usr/bin/hidutil", arguments: [
            "property", "--set",
            "{\"UserKeyMapping\":[]}"
        ])

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            if let keyInfo = KeyCodeConverter.extractKeyInfo(from: event) {
                Task { @MainActor [weak self] in
                    guard let self, self.capturedKeyInfo == nil else { return }
                    self.capturedKeyInfo = keyInfo
                    // Stop monitoring but keep mapping suspended until user confirms
                    if let monitor = self.keyMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.keyMonitor = nil
                    }
                }
            }
            // Return nil to consume ALL events — prevents beeps and stray text
            return nil
        }
    }

    func stopKeyCapture() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

        // Restore hidutil mapping if it was enabled
        if isMappingEnabled {
            let srcHex = sourceKeyInfo.fullHIDHex
            let arg = "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":\(srcHex),\"HIDKeyboardModifierMappingDst\":0x70000006d}]}"
            _ = try? executeProcess("/usr/bin/hidutil", arguments: ["property", "--set", arg])
        }
    }

    // MARK: - Path & Security

    private func getSecureScriptPath() -> String {
        let systemPath = "/Users/Shared/bin/hangulkeymapping"
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("hangulkeymapping").path

        if FileManager.default.isWritableFile(atPath: "/Users/Shared") {
            return systemPath
        } else {
            return tempPath
        }
    }

    private func validatePath(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        let parentURL = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentURL.path) else {
            throw KeyMappingError.pathValidationFailed
        }
        guard FileManager.default.isWritableFile(atPath: parentURL.path) else {
            throw KeyMappingError.directoryNotWritable
        }
        let pathComponents = path.components(separatedBy: "/")
        guard !pathComponents.contains("..") && !pathComponents.contains("~") else {
            throw KeyMappingError.pathValidationFailed
        }
    }

    private func createSecureDirectory(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try validatePath(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func executeProcess(_ launchPath: String, arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        defer {
            if process.isRunning { process.terminate() }
            pipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }

        process.launchPath = launchPath
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                _ = errorPipe.fileHandleForReading.readDataToEndOfFile()
                throw KeyMappingError.processFailed(process.terminationStatus)
            }
            return pipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            throw KeyMappingError.processFailed(-1)
        }
    }

    // MARK: - Mapping Operations

    func checkCurrentStatus() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let plistExists = FileManager.default.fileExists(atPath: launchAgentPlistPath)
        let scriptExists = FileManager.default.fileExists(atPath: scriptPath)

        // Check actual hidutil state to confirm mapping is active
        var hidutilActive = false
        if let data = try? executeProcess("/usr/bin/hidutil", arguments: ["property", "--get", "UserKeyMapping"]),
           let output = String(data: data, encoding: .utf8) {
            hidutilActive = output.contains("HIDKeyboardModifierMappingSrc")
        }

        await MainActor.run {
            // Both conditions: files exist for persistence AND hidutil is active now
            self.isMappingEnabled = (plistExists && scriptExists) && hidutilActive
            self.isLoading = false
        }
    }

    func enableMapping() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let directory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path
            try createSecureDirectory(at: directory)

            let srcHex = sourceKeyInfo.fullHIDHex
            let scriptContent = """
            #!/bin/sh
            # \(sourceKeyInfo.displayName) -> F18
            # Set F18 as input source shortcut in System Settings > Keyboard > Keyboard Shortcuts > Input Sources
            hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\(srcHex),"HIDKeyboardModifierMappingDst":0x70000006d}]}'
            """

            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            _ = try executeProcess("/bin/chmod", arguments: ["755", scriptPath])

            // Apply immediately
            let hidutilArg = "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":\(srcHex),\"HIDKeyboardModifierMappingDst\":0x70000006d}]}"
            _ = try? executeProcess("/usr/bin/hidutil", arguments: ["property", "--set", hidutilArg])

            let plistContent = generateLaunchAgentPlist()
            let tempPlistPath = FileManager.default.temporaryDirectory.appendingPathComponent("com.hangulcommand.userkeymapping.plist").path
            try plistContent.write(toFile: tempPlistPath, atomically: true, encoding: .utf8)

            let success = await executeSecureAppleScript(
                createScript: tempPlistPath,
                targetPath: launchAgentPlistPath
            )
            try? FileManager.default.removeItem(atPath: tempPlistPath)

            if success {
                setF18AsInputSourceShortcut()
                await checkCurrentStatus()
                return true
            } else {
                await MainActor.run {
                    errorMessage = "LaunchAgent 설치에 실패했습니다."
                    isLoading = false
                }
                return false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return false
        }
    }

    func disableMapping() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Clear hidutil mapping (no admin needed, this is the critical operation)
        _ = try? executeProcess("/usr/bin/hidutil", arguments: [
            "property", "--set",
            "{\"UserKeyMapping\":[]}"
        ])

        // Restore default input source shortcut (no admin needed)
        restoreDefaultInputSourceShortcut()

        // Remove LaunchAgent files (best-effort, requires admin)
        // Even if this fails, the mapping is already cleared for this session
        let cleanupSuccess = await executeSecureAppleScript(
            remove: launchAgentLabel,
            plistPath: launchAgentPlistPath,
            scriptPath: scriptPath
        )

        await MainActor.run {
            self.isMappingEnabled = false
            self.isLoading = false
            if !cleanupSuccess {
                // Files may remain but mapping is cleared for this session
                // On next reboot, the mapping may re-activate from LaunchAgent
                print("LaunchAgent cleanup failed, files may remain")
            }
        }
        return true
    }

    // MARK: - Input Source Shortcut

    /// Set F18 as the "Select previous input source" shortcut (hotkey 60)
    /// parameters: (65535=no char, 79=F18 keycode, 8388608=fn flag)
    private func setF18AsInputSourceShortcut() {
        _ = try? executeProcess("/usr/bin/defaults", arguments: [
            "write", "com.apple.symbolichotkeys",
            "AppleSymbolicHotKeys", "-dict-add", "60",
            "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>"
        ])
        _ = try? executeProcess(
            "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings",
            arguments: ["-u"]
        )
    }

    /// Restore default shortcut: Control+Space
    /// parameters: (32=space char, 49=space keycode, 262144=ctrl flag)
    private func restoreDefaultInputSourceShortcut() {
        _ = try? executeProcess("/usr/bin/defaults", arguments: [
            "write", "com.apple.symbolichotkeys",
            "AppleSymbolicHotKeys", "-dict-add", "60",
            "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
        ])
        _ = try? executeProcess(
            "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings",
            arguments: ["-u"]
        )
    }

    // MARK: - Helpers

    private func generateLaunchAgentPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(scriptPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
    }

    private func executeSecureAppleScript(createScript: String? = nil, targetPath: String? = nil, remove: String? = nil, plistPath: String? = nil, scriptPath: String? = nil) async -> Bool {
        var scriptContent = ""

        if let create = createScript, let target = targetPath {
            let escapedCreate = create.replacingOccurrences(of: "'", with: "'\\''")
            let escapedTarget = target.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                mkdir -p '\(URL(fileURLWithPath: escapedTarget).deletingLastPathComponent().path)' 2>/dev/null || exit 1;
                mv '\(escapedCreate)' '\(escapedTarget)' 2>/dev/null || exit 2;
                chown root:admin '\(escapedTarget)' 2>/dev/null || exit 3;
                chmod 644 '\(escapedTarget)' 2>/dev/null || exit 4;
                launchctl load '\(escapedTarget)' 2>/dev/null || exit 5;
                echo 'SUCCESS'
            " with administrator privileges
            """
        } else if let remove = remove, let plist = plistPath, let script = scriptPath {
            let escapedRemove = remove.replacingOccurrences(of: "'", with: "'\\''")
            let escapedPlist = plist.replacingOccurrences(of: "'", with: "'\\''")
            let escapedScript = script.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                launchctl remove '\(escapedRemove)' 2>/dev/null || true;
                rm -f '\(escapedPlist)' 2>/dev/null || true;
                rm -f '\(escapedScript)' 2>/dev/null || true;
                hidutil property --set '{\"UserKeyMapping\":[]}' 2>/dev/null || true;
                echo 'SUCCESS'
            " with administrator privileges
            """
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: scriptContent)
                var errorDict: NSDictionary?
                let result = appleScript?.executeAndReturnError(&errorDict)

                if let error = errorDict {
                    print("AppleScript error: \(error)")
                    DispatchQueue.main.async { continuation.resume(returning: false) }
                    return
                }

                if let resultString = result?.stringValue, resultString.contains("SUCCESS") {
                    DispatchQueue.main.async { continuation.resume(returning: true) }
                } else {
                    DispatchQueue.main.async { continuation.resume(returning: false) }
                }
            }
        }
    }

    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources")!
        NSWorkspace.shared.open(url)
    }
}
