import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var keyMappingManager = KeyMappingManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("키보드 아이콘")
                
                Text("한영 전환 앱")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("오른쪽 커맨드키를 한영키로 사용")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: keyMappingManager.isMappingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(keyMappingManager.isMappingEnabled ? .green : .red)
                        .accessibilityLabel(keyMappingManager.isMappingEnabled ? "활성화됨" : "비활성화됨")
                    
                    Text("현재 상태: \(keyMappingManager.isMappingEnabled ? "활성화" : "비활성화")")
                        .font(.title3)
                        .fontWeight(.medium)
                        .accessibilityLabel("현재 상태: \(keyMappingManager.isMappingEnabled ? "활성화" : "비활성화")")
                }
                
                Button(action: {
                    Task {
                        await toggleMapping()
                    }
                }) {
                    HStack {
                        if keyMappingManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: keyMappingManager.isMappingEnabled ? "xmark" : "checkmark")
                        }
                        
                        Text(keyMappingManager.isMappingEnabled ? "비활성화" : "활성화")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(keyMappingManager.isMappingEnabled ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(keyMappingManager.isLoading)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 2)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("사용 방법")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(
                        number: 1,
                        text: "위 활성화 버튼을 클릭 (관리자 비밀번호 입력)"
                    )
                    
                    InstructionRow(
                        number: 2,
                        text: "오른쪽 커맨드키가 바로 한영 전환키로 동작합니다!"
                    )
                }
                
                Text("💡 Lang1(한영) 키로 직접 매핑되므로 별도의 시스템 설정이 필요 없습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                keyMappingManager.openSystemPreferences()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("시스템 환경설정 열기")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            
            Spacer()
            
            if let errorMessage = keyMappingManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Text("활성화 즉시 적용 · 재부팅 필요 없음")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 500)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인")) {
                    showingAlert = false
                }
            )
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
        
        if success {
            alertTitle = "성공"
            alertMessage = "한영 전환이 성공적으로 \(targetState)되었습니다.\n오른쪽 커맨드키로 한영 전환을 사용해 보세요!"
        } else {
            alertTitle = "오류"
            alertMessage = "\(targetState)하는 중 오류가 발생했습니다. 관리자 비밀번호를 확인해주세요."
        }
        showingAlert = true
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
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
