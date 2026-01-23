import SwiftUI
import Foundation

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

@MainActor
class KeyMappingManager: ObservableObject {
    static let shared = KeyMappingManager()
    
    @Published var isMappingEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let launchAgentLabel = "com.hangulcommand.userkeymapping"
    
    private var launchAgentPlistPath: String {
        return "/Library/LaunchAgents/\(launchAgentLabel).plist"
    }
    
    private var scriptPath: String {
        return getSecureScriptPath()
    }
    
    private init() {
        Task {
            await checkCurrentStatus()
        }
    }
    
    private func getSecureScriptPath() -> String {
        // Try system directory first, fallback to temp
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
        
        // Validate parent directory permissions
        let parentURL = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentURL.path) else {
            throw KeyMappingError.pathValidationFailed
        }
        
        guard FileManager.default.isWritableFile(atPath: parentURL.path) else {
            throw KeyMappingError.directoryNotWritable
        }
        
        // Prevent path traversal
        let pathComponents = path.components(separatedBy: "/")
        guard !pathComponents.contains("..") && !pathComponents.contains("~") else {
            throw KeyMappingError.pathValidationFailed
        }
    }
    
    private func createSecureDirectory(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Validate before creation
        try validatePath(path)
        
        // Create directory with secure permissions
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        // Set secure permissions (755)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
    
    private func executeProcess(_ launchPath: String, arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            // Ensure cleanup
            if process.isRunning {
                process.terminate()
            }
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
            
            // Check for errors
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                throw KeyMappingError.processFailed(process.terminationStatus)
            }
            
            return pipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            throw KeyMappingError.processFailed(-1)
        }
    }
    
    func checkCurrentStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let output = try executeProcess("/bin/launchctl", arguments: ["list", launchAgentLabel])
            let outputString = String(data: output, encoding: .utf8) ?? ""
            
            // Parse launchctl output more robustly
            let isEnabled = !outputString.contains("Could not find service") && 
                           !outputString.contains("com.hangulcommand.userkeymapping") == false
            
            await MainActor.run {
                self.isMappingEnabled = isEnabled
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isMappingEnabled = false
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func enableMapping() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Create directory securely
            let directory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path
            try createSecureDirectory(at: directory)
            
            // Create script content safely
            let scriptContent = """
            #!/bin/sh
            # Secure key mapping script
            hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x70000006d}]}'
            """
            
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Set executable permissions securely
            try executeProcess("/bin/chmod", arguments: ["755", scriptPath])
            
            // Create LaunchAgent plist in temp first
            let plistContent = generateLaunchAgentPlist()
            let tempPlistPath = FileManager.default.temporaryDirectory.appendingPathComponent("com.hangulcommand.userkeymapping.plist").path
            
            try plistContent.write(toFile: tempPlistPath, atomically: true, encoding: .utf8)
            
            // Use secure AppleScript execution
            let success = await executeSecureAppleScript(
                createScript: tempPlistPath,
                targetPath: launchAgentPlistPath
            )
            
            // Cleanup temp file
            try? FileManager.default.removeItem(atPath: tempPlistPath)
            
            if success {
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
        
        do {
            // Use secure AppleScript for removal
            let success = await executeSecureAppleScript(
                remove: launchAgentLabel,
                plistPath: launchAgentPlistPath,
                scriptPath: scriptPath
            )
            
            if success {
                await checkCurrentStatus()
                return true
            } else {
                await MainActor.run {
                    errorMessage = "LaunchAgent 제거에 실패했습니다."
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
    
    private func generateLaunchAgentPlist() -> String {
        return """
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
            // Secure script creation
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
            // Secure script removal
            let escapedRemove = remove.replacingOccurrences(of: "'", with: "'\\''")
            let escapedPlist = plist.replacingOccurrences(of: "'", with: "'\\''")
            let escapedScript = script.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                launchctl remove '\(escapedRemove)' 2>/dev/null || true;
                rm -f '\(escapedPlist)' 2>/dev/null || true;
                rm -f '\(escapedScript)' 2>/dev/null || true;
                echo 'SUCCESS'
            " with administrator privileges
            """
        } else         if let remove = remove, let plist = plistPath, let script = scriptPath {
            // Secure script removal
            let escapedRemove = remove.replacingOccurrences(of: "'", with: "'\\''")
            let escapedPlist = plist.replacingOccurrences(of: "'", with: "'\\''")
            let escapedScript = script.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                launchctl remove '\(escapedRemove)' 2>/dev/null || true;
                rm -f '\(escapedPlist)' 2>/dev/null || true;
                rm -f '\(escapedScript)' 2>/dev/null || true;
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
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                    return
                }
                
                // Check if script succeeded
                if let resultString = result?.stringValue, resultString.contains("SUCCESS") {
                    DispatchQueue.main.async {
                        continuation.resume(returning: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources")!
        NSWorkspace.shared.open(url)
    }
}