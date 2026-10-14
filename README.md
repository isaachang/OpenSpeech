# OpenSpeech

![version](https://img.shields.io/badge/version-0.2.0-blue) ![platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![license](https://img.shields.io/badge/license-MIT-green)

[中文说明](README.zh-CN.md) · [Changelog](CHANGELOG.md)

An open-source teleprompter that lives in your MacBook's notch and **follows your voice**.
Built for meetings, student presentations, and screen recordings — any time you need to read a script while looking at the camera.

> **Status: early (v0.1.0).** The core voice-following works; the UI is still being redesigned.

## Features

- **Follows your voice** — on-device speech recognition tracks where you are in the script. Chinese, English, and mixed Chinese-English scripts.
- **Never jumps on ad-libs** — if you go off script, it waits for you. It only moves forward when you have actually read your way there.
- **Script-aware recognition** — each script is turned into a custom language model for the recognizer (macOS 14+), so names and technical terms are heard correctly.
- **Placed for eye contact** — about 5° below the camera by default. Two styles (glass card / caption capsule). Drag anywhere (snaps to the camera centerline), drag corners to resize, double-click to reset; remembered per screen.
- **Smart constant-speed mode** — scrolls at your pace and pauses when you stop talking.
- Hidden from screen sharing (see [Screen sharing](#screen-sharing)), global hotkeys, import txt / md / docx / pdf / rtf, or drop a file onto the notch.

## Requirements

- macOS 14 or later (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`)

## Build & run

```bash
./build.sh
open build/OpenSpeech.app
```

Allow **Microphone** and **Speech Recognition** when asked. The app is ad-hoc signed, so macOS may ask again after each rebuild.

## Screen sharing

The prompter is invisible to the other people in your meeting — they only see your screen, not your script.

| App | Hidden while sharing? |
| --- | --- |
| Tencent Meeting (腾讯会议 / VooV) | ✅ Works out of the box (tested) |
| Microsoft Teams | ✅ Works out of the box (tested) |
| DingTalk Meetings (钉钉会议) | ✅ Works out of the box (tested) |
| Zoom | ⚙️ Needs a one-time setting (below) |

**Zoom setup (once, stays on):** Zoom → **Settings** → **Share Screen** → **Advanced** (at the bottom) → **Screen capture mode** → choose **Advanced capture with window filtering**.

Without this, Zoom's default capture mode records everything on screen, including the prompter.

## Shortcuts

| Keys | Action |
| --- | --- |
| `⌥⌘P` | Start / pause / resume |
| `⌥⌘↑` `⌥⌘↓` | Previous / next line (also two-finger scroll on the prompter) |
| `⌥⌘←` `⌥⌘→` | Slower / faster (constant-speed mode) |
| `⌥⌘.` | Stop |

Script markup: `【…】` / `[…]` for stage directions (optional to read), `**…**` for emphasis.

## Privacy

Everything runs on your Mac. Tracking logs (for tuning) stay in `~/Library/Application Support/OpenSpeech/logs/` and can be turned off in settings.

## Development

```bash
tools/eval/run.sh   # unit tests + held-out simulation + replay of local logs
```

Every tracking change should improve (or not hurt) both the simulation on unseen scripts and the real-log replay — no rules tuned for a single case.

**Releasing:** bump `VERSION`, the version badge in both READMEs, and add an entry to `CHANGELOG.md`, then run `tools/check-version.sh`.

## License

[MIT](LICENSE)
