import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var keyMappingManager = KeyMappingManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showKeyCaptureSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("한영 전환 앱")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("원하는 키를 한영키로 사용")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Key Configuration + Status combined
            VStack(spacing: 14) {
                // Key selection
                HStack {
                    Label("전환 키", systemImage: "command")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(keyMappingManager.sourceKeyInfo.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    Button("변경") {
                        showKeyCaptureSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(keyMappingManager.isMappingEnabled)
                }

                Divider()

                // Status
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: keyMappingManager.isMappingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(keyMappingManager.isMappingEnabled ? .accentColor : .gray)
                        Text("상태")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Spacer()

                    Text(keyMappingManager.isMappingEnabled ? "활성화" : "비활성화")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(keyMappingManager.isMappingEnabled ? .green : .red)
                }

                // Toggle button
                Button(action: {
                    Task { await toggleMapping() }
                }) {
                    HStack {
                        if keyMappingManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: keyMappingManager.isMappingEnabled ? "stop.fill" : "play.fill")
                                .font(.caption)
                        }

                        Text(keyMappingManager.isMappingEnabled ? "비활성화" : "활성화")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(keyMappingManager.isMappingEnabled ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(keyMappingManager.isLoading)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("사용 방법")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 6) {
                    InstructionRow(number: 1, text: "\"변경\" 버튼으로 한영 전환 키 설정")
                    InstructionRow(number: 2, text: "활성화 클릭 (관리자 비밀번호 입력)")
                }

                Text("활성화하면 키 매핑과 입력 소스 단축키가 자동 설정됩니다.\n앱을 종료해도 계속 동작합니다.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = keyMappingManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            SettingsView()
        }
        .padding(20)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인")) {
                    showingAlert = false
                }
            )
        }
        .sheet(isPresented: $showKeyCaptureSheet) {
            KeyCaptureSheetView(manager: keyMappingManager, isPresented: $showKeyCaptureSheet)
        }
        .task {
            await keyMappingManager.checkCurrentStatus()
        }
        .onReceive(keyMappingManager.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                alertTitle = "오류"
                alertMessage = errorMessage
                showingAlert = true
            }
        }
    }

    private func toggleMapping() async {
        let success: Bool
        let targetState: String

        if keyMappingManager.isMappingEnabled {
            success = await keyMappingManager.disableMapping()
            targetState = "비활성화"
        } else {
            success = await keyMappingManager.enableMapping()
            targetState = "활성화"
        }

        if !success {
            alertTitle = "오류"
            alertMessage = "\(targetState) 중 오류가 발생했습니다. 관리자 비밀번호를 확인해주세요."
            showingAlert = true
        }
    }
}

// MARK: - Key Capture Sheet

struct KeyCaptureSheetView: View {
    @ObservedObject var manager: KeyMappingManager
    @Binding var isPresented: Bool
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            if let captured = manager.capturedKeyInfo {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text(captured.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    Button("다시 입력") {
                        manager.startKeyCapture()
                    }
                    .buttonStyle(.bordered)

                    Button("확인") {
                        manager.setSourceKey(captured)
                        manager.stopKeyCapture()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Image(systemName: "keyboard")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .opacity(pulseAnimation ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

                Text("한영 전환에 사용할 키를\n눌러주세요")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("커맨드, 옵션, 쉬프트 등 수정자 키도 감지됩니다")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("취소") {
                    manager.stopKeyCapture()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(width: 320, height: 240)
        .onAppear {
            pulseAnimation = true
            manager.startKeyCapture()
        }
        .onDisappear {
            manager.stopKeyCapture()
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
