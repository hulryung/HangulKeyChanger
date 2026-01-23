import SwiftUI
import Foundation

class KeyMappingManager: ObservableObject {
    static let shared = KeyMappingManager()
    
    @Published var isMappingEnabled = false
    @Published var isAdminGranted = false
    
    private let launchAgentLabel = "com.hangulcommand.userkeymapping"
    private let launchAgentPlistPath = "/Library/LaunchAgents/com.hangulcommand.userkeymapping.plist"
    private let scriptPath = "/Users/Shared/bin/hangulkeymapping"
    
    private init() {
        checkCurrentStatus()
    }
    
    func checkCurrentStatus() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list", launchAgentLabel]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        isMappingEnabled = output.contains(launchAgentLabel)
    }
    
    func enableMapping() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let success = await self.performMappingSetup()
                DispatchQueue.main.async {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func performMappingSetup() async -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: "/Users/Shared/bin", withIntermediateDirectories: true)
        } catch {
            print("Failed to create directory: \(error)")
            return false
        }
        
        let scriptContent = """
        #!/bin/sh
        hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x70000006d}]}'
        """
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            let chmodProcess = Process()
            chmodProcess.launchPath = "/bin/chmod"
            chmodProcess.arguments = ["755", scriptPath]
            chmodProcess.launch()
            chmodProcess.waitUntilExit()
            
            if chmodProcess.terminationStatus != 0 {
                return false
            }
        } catch {
            print("Failed to create script: \(error)")
            return false
        }
        
        let plistContent = """
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
        </dict>
        </plist>
        """
        
        let tempPlistPath = "/tmp/com.hangulcommand.userkeymapping.plist"
        do {
            try plistContent.write(toFile: tempPlistPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create plist: \(error)")
            return false
        }
        
        let appleScript = """
        do shell script "mkdir -p '/Library/LaunchAgents' 2>/dev/null; mv '\(tempPlistPath)' '\(launchAgentPlistPath)' && chown root:admin '\(launchAgentPlistPath)' && launchctl load '\(launchAgentPlistPath)'" with administrator privileges
        """
        
        return await executeAppleScript(appleScript)
    }
    
    func disableMapping() async -> Bool {
        let appleScript = """
        do shell script "launchctl remove '\(launchAgentLabel)' 2>/dev/null; rm -f '\(launchAgentPlistPath)'; rm -f '\(scriptPath)'" with administrator privileges
        """
        
        return await executeAppleScript(appleScript)
    }
    
    private func executeAppleScript(_ script: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                
                let result = appleScript?.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    print("AppleScript error: \(error)")
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.checkCurrentStatus()
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources")!
        NSWorkspace.shared.open(url)
    }
}