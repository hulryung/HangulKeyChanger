# Hangul Key Changer

Remap any key to toggle Korean/English input on macOS.

원하는 키를 한영 전환키로 사용할 수 있는 macOS 유틸리티입니다.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

<p align="center">
  <img src="screenshot.png" alt="Hangul Key Changer" width="400">
</p>

## Features

- **Key remapping** — Set any key (Right Command, Caps Lock, etc.) as the input toggle key
- **One-click enable/disable** — Activates key mapping + system shortcut automatically
- **Persists after reboot** — LaunchAgent keeps it working without the app running
- **Menu bar control** — Quick access from the status bar
- **Korean / English UI** — Automatically follows system language

## Install

Download the latest `.zip` from [Releases](https://github.com/hulryung/hangul-command-app/releases), unzip, and move to `/Applications`.

> On first launch, right-click → Open to bypass Gatekeeper, or run:
> ```bash
> xattr -cr /Applications/HangulCommandApp.app
> ```

## Usage

1. Click **Change** to pick your toggle key
2. Click **Enable** and enter your admin password
3. Done — the key now toggles Korean/English input

## Uninstall

Click **Disable** in the app to restore all settings, then delete the app.

## Build from source

```bash
git clone https://github.com/hulryung/hangul-command-app.git
cd hangul-command-app
xcodebuild -scheme HangulCommandApp build
```

## License

[MIT](LICENSE)

---

<div align="center">

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕-yellow)](https://buymeacoffee.com/hulryung)

</div>
