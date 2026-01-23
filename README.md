# 한영 전환 앱

오른쪽 커맨드키를 한영키로 사용하는 간단한 macOS 유틸리티 앱입니다.

## 특징

- **간단한 토글**: 한 번 클릭으로 오른쪽 커맨드키 → F18 키 매핑 활성화/비활성화
- **메뉴 바 통합**: 메뉴 바에서 직접 제어 가능
- **자동 시작**: LaunchAgent를 통해 부팅 시 자동 적용
- **관리자 권한 처리**: 안전한 권한 요청 및 처리
- **되돌리기 기능**: 언제든지 원래 상태로 되돌릴 수 있음

## 설치 방법

### 1. 코드 사인 및 빌드
```bash
# 개발자 인증서로 코드 사인
codesign --force --deep --sign "Developer ID Application: Your Name" HangulCommandApp.app

# 공증(notarization) 처리
xcrun altool --notarize-app --primary-bundle-id "com.example.HangulCommandApp" --username "your@email.com" --password "@keychain:AC_PASSWORD" --file HangulCommandApp.app.zip
```

### 2. 설치
```bash
# /Applications 폴더로 복사
cp -R HangulCommandApp.app /Applications/

# 첫 실행
open /Applications/HangulCommandApp.app
```

## 사용 방법

### 1단계: 앱에서 활성화
1. 앱 실행 또는 메뉴 바 아이콘 클릭
2. "활성화" 버튼 클릭
3. 관리자 비밀번호 입력 (최초 1회만)

### 2단계: 시스템 환경설정
1. 시스템 환경설정 > 키보드 > 단축키
2. "입력소스" 선택
3. "이전 입력소스 선택"의 단축키로 오른쪽 커맨드키 설정

### 완료!
이제 오른쪽 커맨드키를 누르면 한영 전환이 됩니다.

## 제거 방법

앱에서 "비활성화" 버튼을 누르면 모든 설정이 원래대로 복원됩니다.

## 기술 원리

이 앱은 블로그 [맥에서 오른쪽 커맨드키를 한영 변환키로 쓰기](https://juil.dev/mac-right-command-to-hangul/)의 방법을 구현한 것입니다.

1. **HID 유틸리티**: `hidutil`을 사용하여 오른쪽 커맨드키(0xE7)를 F18키(0x6D)로 매핑
2. **LaunchAgent**: `/Library/LaunchAgents/`에 등록하여 부팅 시 자동 실행
3. **시스템 환경설정**: F18키를 입력소스 전환 단축키로 설정

## 요구 사항

- macOS 13.0 이상
- 관리자 권한 (최초 설정 시)

## 보안

이 앱은 다음 권한만 요청합니다:
- **AppleEvents**: 관리자 권한으로 스크립트 실행
- **파일 시스템**: LaunchAgent 및 스크립트 파일 생성

모든 작업은 로컬에서만 실행되며, 네트워크 통신 없이 완전히 오프라인으로 동작합니다.

## 라이선스

MIT License

## 제작

블로그 글을 기반으로 macOS 네이티브 앱으로 구현.