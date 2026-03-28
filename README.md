# Hangul Key Changer

macOS에서 **원하는 키 하나로 한영 전환**을 할 수 있게 해주는 가벼운 유틸리티입니다.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> [English README](README_EN.md)

<p align="center">
  <img src="screenshot_ko.png" alt="Hangul Key Changer" width="400">
</p>

## 왜 만들었나요?

macOS를 쓰면서 한영 전환이 불편했던 경험, 한 번쯤 있으시죠?

- **Caps Lock**으로 전환하려니 반응이 느리고, 원래 Caps Lock 기능을 잃게 됩니다
- **Fn 키**는 위치가 어색하고 키보드마다 동작이 다릅니다
- **Windows 키보드**에 익숙하다면 오른쪽 Alt(Command) 자리에 한영키가 있는 게 자연스럽습니다

이 문제를 해결하기 위해 보통 [Karabiner-Elements](https://karabiner-elements.pqrs.org/)를 설치하고 복잡한 JSON 규칙을 작성해야 했습니다. 드라이버 수준의 무거운 프로그램을 설치하는 것도 부담이었고요.

**Hangul Key Changer**는 macOS에 내장된 `hidutil` 명령어만 사용해서 키를 변환합니다. 별도의 드라이버나 커널 확장 없이, 가볍고 안전하게 동작합니다.

## 주요 기능

- **원하는 키를 한영키로** — 오른쪽 Command, Caps Lock 등 원하는 키를 선택
- **원클릭 활성화** — 버튼 하나로 키 매핑 + 시스템 단축키 자동 설정, 관리자 비밀번호 불필요
- **재부팅해도 유지** — 로그인 항목으로 등록되어 부팅 시 자동 적용
- **앱 실행 불필요** — 한번 설정하면 앱을 종료해도 키 매핑이 계속 동작
- **한국어/영어 UI** — 앱 내에서 KO/EN 버튼으로 즉시 전환
- **특별한 권한 불필요** — 드라이버, 커널 확장, 접근성 권한 없이 동작

## 설치

### Homebrew (권장)

```bash
brew install hulryung/tap/hangulkeychanger
```

> **v2.3.0 이하에서 업그레이드 시** 앱 이름이 변경되어 `brew upgrade`가 실패할 수 있습니다. 이 경우 제거 후 재설치하세요:
> ```bash
> brew uninstall --cask hangulkeychanger --force
> brew install hulryung/tap/hangulkeychanger
> ```

### DMG 다운로드

[Releases](https://github.com/hulryung/HangulKeyChanger/releases) 페이지에서 최신 DMG 파일을 다운로드하고, 열어서 앱을 `/Applications`에 드래그하세요.

Apple 공증(Notarization)을 완료한 앱이므로 별도의 보안 경고 없이 바로 실행됩니다.

## 사용법

1. 앱을 실행합니다
2. **변경** 버튼을 눌러 한영키로 사용할 키를 선택합니다 (기본: 오른쪽 Command)
3. **활성화** 버튼을 누릅니다
4. 끝! 선택한 키로 한영 전환이 됩니다

<p align="center">
  <code>오른쪽 Command ⌘</code> → 한영 전환
</p>

앱을 종료해도 키 매핑은 계속 동작합니다. 재부팅 후에도 자동으로 다시 적용됩니다.

## 제거

1. 앱에서 **비활성화** 버튼을 눌러 키 매핑을 해제합니다
2. 앱을 삭제합니다

Homebrew로 설치한 경우:
```bash
brew uninstall hangulkeychanger
```

## 작동 원리

Hangul Key Changer는 세 단계로 동작합니다:

1. **키 리매핑**: macOS 내장 `hidutil`을 사용하여 선택한 키를 F18로 변환합니다
2. **입력 소스 단축키 설정**: 시스템 환경설정의 "이전 입력 소스 선택" 단축키를 F18로 변경합니다
3. **부팅 시 자동 적용**: `SMAppService`로 로그인 항목에 등록하여 재부팅 후에도 매핑이 유지됩니다

외부 드라이버나 커널 확장을 사용하지 않으며, Karabiner처럼 백그라운드 데몬이 상주하지 않습니다. 시스템이 제공하는 기본 메커니즘만 활용합니다.

### 기술 스택

| 항목 | 기술 |
|---|---|
| 언어 | Swift 5 |
| UI 프레임워크 | AppKit (순수 Cocoa) |
| 키 매핑 | `hidutil` (HID Usage Table 기반) |
| 지속성 | SMAppService (로그인 항목) |
| 최소 요구사항 | macOS 14.0 Sonoma 이상 |
| 서명 | Developer ID + Apple Notarization |

## 자유롭게 사용하세요

이 앱은 특별한 권한을 요구하지 않습니다. 접근성 권한, 입력 모니터링, 관리자 비밀번호 모두 필요 없습니다. macOS가 기본으로 제공하는 `hidutil`만 사용하므로 시스템에 부담을 주지 않습니다.

소스 코드는 MIT 라이선스로 공개되어 있으니, 자유롭게 사용하고 수정하세요.

## 소스에서 빌드

```bash
git clone https://github.com/hulryung/HangulKeyChanger.git
cd HangulKeyChanger
xcodebuild -scheme HangulCommandApp build
```

## 변경 이력

### v2.4.0
- 메뉴 바 앱에서 독립 실행 앱으로 변경
- 관리자 비밀번호 없이 활성화 가능 (SMAppService 사용)
- 앱 내 KO/EN 언어 전환 기능 추가
- About 패널 및 메뉴 바 추가
- 하단에 버전, 웹사이트/GitHub/X 링크 표시
- 앱 이름을 "Hangul Key Changer"로 변경

### v2.3.1
- 빌드 아티팩트에 앱 아이콘 포함

### v2.3.0
- 다크 모드 지원
- 코드 품질 개선 및 공증 준비

## 라이선스

[MIT](LICENSE)

## 링크

- [웹사이트](https://hkc.hulryung.com)
- [GitHub](https://github.com/hulryung/HangulKeyChanger)
- [X (Twitter)](https://x.com/hulryung)

---

<div align="center">

저는 여전히 3벌식을 사랑합니다.

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕-yellow)](https://buymeacoffee.com/hulryung)

</div>
