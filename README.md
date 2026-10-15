<p align="center">
  <img src="docs/images/icon.png" width="112" alt="OpenSpeech icon">
</p>

<h1 align="center">OpenSpeech</h1>

<p align="center">
  <b>A teleprompter that lives in your MacBook's notch and follows your voice.</b><br>
  Your script sits right below the camera, so reading it looks like eye contact.
</p>

<p align="center">
  <a href="https://github.com/isaachang/OpenSpeech/releases/latest"><b>⬇︎ Download the latest release</b></a>
  &nbsp;·&nbsp; <a href="README.zh-CN.md">中文说明</a>
  &nbsp;·&nbsp; <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.3.2-1C1C1E" alt="version">
  <img src="https://img.shields.io/badge/macOS-14%2B-1C1C1E" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple%20silicon%20%2B%20Intel-1C1C1E" alt="Apple silicon + Intel">
  <img src="https://img.shields.io/badge/license-MIT-1C1C1E" alt="MIT">
</p>

<p align="center">
  <img src="docs/images/hero.png" width="100%" alt="The prompter card below the camera, with the cheat sheet in the corner">
</p>

Meetings, interviews, presentations, video recordings: OpenSpeech is built for any time you need to **read a script while looking at the camera**. (The UI is in Chinese for now; scripts can be Chinese, English or mixed.)

> **Status: early (v0.3.2).** Voice-following is solid; the UI and features are still moving fast.

<table>
  <tr>
    <td width="33%" valign="top"><b>🎙 Follows your voice</b><br>On-device speech recognition tracks where you are. Chinese, English and mixed scripts.</td>
    <td width="33%" valign="top"><b>🎯 Reading = eye contact</b><br>About 5° below the camera by default. Drag, resize, double-click to reset.</td>
    <td width="33%" valign="top"><b>🧭 Never jumps on ad-libs</b><br>Go off script and it waits. It only moves when you've actually read your way there.</td>
  </tr>
  <tr>
    <td valign="top"><b>📑 Sections you can jump to</b><br>Split a script with <code>##</code> headings, then press <code>⌥⌘1…9</code> to jump while prompting.</td>
    <td valign="top"><b>🗒 Cheat sheet</b><br>The whole script in a corner, following along. Click any part to jump there.</td>
    <td valign="top"><b>🙈 Hidden from screen sharing</b><br>In Tencent Meeting, Teams, DingTalk and Zoom, others see your screen, not your script.</td>
  </tr>
</table>

---

## The prompter card: liquid glass + highlighter

<p align="center"><img src="docs/images/prompter-card.png" width="720" alt="Prompter card"></p>

- **The word you're reading gets a yellow highlighter**; what you've read fades, what's next stays dark. One glance tells you where you are.
- **Liquid glass**: the card lets a little of the background through, and the text stays crisp.
- **Adjust by hand**: drag to move (it snaps to the camera centerline with a trackpad tick), drag the corners to change characters per line and line count, **double-click to restore the default position and size**. Remembered per screen.
- Hover to show controls: previous line · pause · next line · cheat sheet · stop.

There's also a compact **caption** style that shows just this line and the next, in a bigger font.

<p align="center"><img src="docs/images/caption.png" width="640" alt="Caption style"></p>

## Split a script into sections, jump to any of them

Preparing several stories for an interview? Separate them with Markdown headings:

```markdown
# Product manager interview

## About me
Hi, I'm Alex…

## A conflict across teams
We got stuck with the design team on the launch date…

## My first failed project
In my second year I built a campus marketplace app…
```

<p align="center"><img src="docs/images/heading-signpost.png" width="720" alt="Headings show up as gray signposts on the card"></p>

- **Headings are signposts, not lines to read.** They appear small and gray on the card; finish one section, start the next, and the prompter skips right past the heading.
- **⌥⌘1 … ⌥⌘9** jumps to that section, with a "→ 3 …" hint in the notch. These keys are only taken while prompting.

## Cheat sheet: the whole script, right there

<p align="center"><img src="docs/images/cheat-sheet.png" width="360" alt="Cheat sheet"></p>

- Shows **the whole script** in a corner while you prompt: numbered headings with their shortcuts, the current paragraph highlighted, scrolling along with you.
- **Click a heading or paragraph to jump there**; the card and voice-follow continue from that point.
- **Drag it anywhere** (grab the six dots at the top); double-click the top to send it back to the corner. Toggle with `⌥⌘O`.
- Like the card, **it's invisible to people you're screen sharing with**.

## Script library and editor

<p align="center"><img src="docs/images/main-window.png" width="100%" alt="Main window"></p>

- **Live-styled Markdown, like Notion**: type `# ` for a large heading, `## ` for medium, `### ` for small. `**emphasis**` shows bold, `【cues】` / `[cues]` show orange.
- The `#` and `**` markers stay hidden except on the line you're editing. What's saved is plain Markdown, so formatting survives copy and paste.
- `⌘⌥1` / `⌘⌥2` / `⌘⌥3` set a heading, `⌘⌥0` back to body text.
- Import txt · md · docx · doc · rtf · pdf · html, or drop a file onto the notch.

Hover over the notch for a quick panel; you can start without opening the main window:

<p align="center"><img src="docs/images/notch-peek.png" width="640" alt="Notch panel"></p>

## One-click updates

<table>
  <tr>
    <td width="55%" valign="top"><img src="docs/images/update-notes.png" alt="Update card (example)"></td>
    <td width="45%" valign="top"><img src="docs/images/changelog.png" alt="Version history"></td>
  </tr>
</table>

- When a new version is out, a banner appears in the main window. **Click Update** and the app downloads, verifies, installs and relaunches itself, keeping your scripts, settings and microphone permission.
- **Never interrupts while you're prompting.**
- **Version history** in the bottom-right corner lists what changed in each release.

---

## Install

1. Download `OpenSpeech-x.y.z.zip` from the [latest release](https://github.com/isaachang/OpenSpeech/releases/latest) and unzip it.
2. **Drag `OpenSpeech.app` into Applications.** Don't run it from Downloads, or in-app updates won't work.
3. First launch: macOS says it can't verify the developer (the app isn't notarized). Click Done, then go to **System Settings › Privacy & Security** and click **Open Anyway** at the bottom. On macOS 14 you can also right-click the app › Open. Only needed once.
4. Allow **Microphone** and **Speech Recognition**.

Every update after that happens inside the app.

## Writing a script

| Markup | Shows as | Do you read it? |
| --- | --- | --- |
| `# large` `## medium` `### small` | Sections; gray signposts on the card | No |
| `**emphasis**` | Bold, a reminder to stress it | Yes |
| `【pause】` / `[Pause]` | Stage direction, orange | Optional |

## Shortcuts

| Keys | Action |
| --- | --- |
| `⌥⌘P` | Start / pause / resume |
| `⌥⌘↑` `⌥⌘↓` | Previous / next line (or two-finger scroll on the card) |
| `⌥⌘1` … `⌥⌘9` | Jump to a section while prompting |
| `⌥⌘O` | Show / hide the cheat sheet |
| `⌥⌘←` `⌥⌘→` | Slower / faster (constant-speed mode) |
| `⌥⌘.` | Stop |
| `⌘⌥1` `⌘⌥2` `⌘⌥3` `⌘⌥0` | Editor: large / medium / small heading / body |
| Double-click the card | Restore default position and size |

## Screen sharing

The prompter card and cheat sheet are invisible to the other people in your meeting.

| App | Hidden while sharing? |
| --- | --- |
| Tencent Meeting (腾讯会议 / VooV) | ✅ Works out of the box (tested) |
| Microsoft Teams | ✅ Works out of the box (tested) |
| DingTalk Meetings (钉钉会议) | ✅ Works out of the box (tested) |
| Zoom | ⚙️ Needs a one-time setting (below) |

**Zoom setup (once, stays on):** Zoom → **Settings** → **Share Screen** → **Advanced** (at the bottom) → **Screen capture mode** → **Advanced capture with window filtering**. Without this, Zoom's default capture records everything on screen, including the prompter.

## Privacy

Everything runs on your Mac; scripts are never uploaded. Tracking logs (for tuning) stay in `~/Library/Application Support/OpenSpeech/logs/` and can be turned off under File › Developer options.

---

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
open build/OpenSpeech.app
```

## Development

```bash
tools/eval/run.sh   # unit tests + held-out simulation + replay of local logs
```

Every tracking change should improve (or not hurt) both the simulation on unseen scripts and the real-log replay — no rules tuned for a single case.

**Releasing:** bump `VERSION`, the version badge in both READMEs, and add an entry to `CHANGELOG.md` (with a one-line `>` summary — the app shows it), then run `tools/check-version.sh`.

**In-app updates (Sparkle):** run `tools/setup-signing.sh` once (creates a local signing certificate and the update signing key in `~/.openspeech-signing` — back that folder up). `tools/test-update.sh` runs a full old → new update locally; `tools/release.sh` builds a universal zip, signs it, writes `appcast.xml` and publishes a GitHub Release.

**README screenshots:** `build/OpenSpeech.app/Contents/MacOS/OpenSpeech --snapshot-readme <dir>` renders clean shots from the sample scripts on a neutral desktop.

## License

[MIT](LICENSE)
