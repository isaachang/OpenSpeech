# Changelog / 版本日志

格式参考 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循 [语义化版本](https://semver.org/)。
Format based on Keep a Changelog; versions follow Semantic Versioning.

每个版本标题下面用 `>` 写一句给用户看的总结（第一行中文、第二行英文），App 里的「版本日志」和更新提示会显示它；每条的 “：” 或 “。” 之前是卡片上显示的短标题，英文界面显示条目下面那行英文。
The `>` lines under each version (Chinese, then English) are the summary shown in the app; English UI shows the indented English line of each item.

## [0.3.5] - 2026-10-15

> Zoom 提醒更清楚了：平时只占一行，点「查看」就能看到三步怎么改。
> A clearer Zoom reminder: one line until you need it, then three steps to follow.

### 变更 Changed
- Zoom 设置提醒改成一行：点「查看」弹出要改的三步，最后一步要选的选项高亮显示，和 Zoom 里看到的一样；可以直接打开 Zoom，改好后点「改好了」就不再提示。
  Zoom setting reminder: now a single line; View opens the three steps with the option to pick highlighted, plus Open Zoom and Done.

## [0.3.4] - 2026-10-15

> 用 Zoom 的话，App 会提醒你改哪个设置；新增一行命令安装，也可以让 AI 助手帮你装。
> If you use Zoom, the app shows the one setting to change; plus a one-line installer an AI assistant can run for you.

### 新增 Added
- Zoom 设置提醒：这台 Mac 装了 Zoom 时，主窗口顶上提示要在 Zoom 里改哪个设置，共享屏幕时对方才看不到提词器；点关闭就不再出现。
  Zoom setting reminder: if Zoom is installed, the main window shows the setting that keeps the prompter out of shared screens.
- 一行命令安装：在终端运行 README 里的那一行，自动下载最新版、装进「应用程序」并打开，最后列出接下来要做的事。
  One-line installer: downloads the latest version, installs it into Applications, opens it and lists next steps.
- 让 AI 助手帮你装：把仓库链接发给 Claude Code、Codex 这类助手就行，README 里写明了它装完要提醒你什么。
  Install with an AI assistant: send it the repo link, and the README tells it what to remind you afterwards.
- 固定下载链接：Releases 里多了一个不带版本号的 OpenSpeech.zip，永远是最新版。
  Fixed download link: every release also has a version-less OpenSpeech.zip that is always the latest.

## [0.3.3] - 2026-10-15

> 新增英文界面：系统语言里有中文就显示中文，也可以在设置里切换。
> OpenSpeech now speaks English: the interface follows your Mac's languages, or pick one in settings.

### 新增 Added
- 英文界面：菜单、按钮、提示、更新卡片、版本日志都有英文版。设置里新增「界面语言」：自动 / 中文 / English。
  English interface throughout, with a Language setting (Automatic / 中文 / English).
- 英文示例稿：英文界面下附带英文的产品口播和面试故事库。English sample scripts, including an interview story bank.

### 变更 Changed
- 自动选择语言：只要系统语言列表里有中文就用中文，完全没有中文才用英文。
  Automatic picks Chinese if it's anywhere in your language list.

## [0.3.2] - 2026-10-15

> 纸白配色和液态玻璃；用 # 标题给稿子分段，提词时一键跳到任意一段；新增可拖动的小抄。
> Paper-white look with liquid glass; split scripts with # headings and jump to any section; a draggable cheat sheet.

### 新增 Added
- 标题：稿子里用 # 大标题、## 中标题、### 小标题分段。提词卡片上显示成灰色小路牌，不用念，跟读时自动跨过去。
  Headings (#, ##, ###) split a script into sections; shown as signposts on the card and skipped by voice-follow.
- 一键跳段：提词时按 ⌥⌘1…9 跳到第几段（只在提词时占用这组快捷键）。
  ⌥⌘1–9 jumps to a section while prompting.
- 小抄：提词时屏幕角落显示整篇稿子，跟着讲到哪滚到哪，点标题或段落就跳过去；可以拖到任何地方，双击回到右上角（⌥⌘O）。
  Cheat sheet with the whole script: follows along, click to jump, draggable (⌥⌘O).
- 编辑区边写边排版：标题、**重点**、【导演提示】直接显示成对应样子，# 和 ** 只在光标所在行显示；⌘⌥1 / 2 / 3 / 0 设成大 / 中 / 小标题 / 正文。
  Live-styled Markdown editor; ⌘⌥1/2/3/0 for headings and body text.
- 操作提示：第一次用时提示可以拖动、调大小、双击回到默认；光标在拖动条上变成手，四个角是调大小箭头；双击后有确认，吸到镜头中线时触控板轻震。
  First-run tips, proper cursors, feedback on reset, and a haptic tick when snapping to the centerline.
- 示例稿「面试故事库」：演示怎么用标题分段。A sample interview script that shows headings.

### 变更 Changed
- 界面改为纸白配色：主窗口浅色、黑字，每屏只有一个黑色主按钮。Paper-white theme.
- 提词卡片和小抄改为液态玻璃：能隐约透出后面，正在读的字用荧光笔黄标出来。
  Prompter card and cheat sheet use a light liquid-glass look; the current word gets a highlighter.
- 双击提词卡片现在同时回到默认位置和预设大小。Double-click now also restores the preset size.
- 加上 OpenSpeech 标志：在提词卡片顶部；刘海展开页里的标志和稿件标题对齐，不再被刘海挡住。
  Logo on the card; notch header no longer hidden by the notch.

### 修复 Fixed
- 导入 .md 文件时不再丢掉 # 标题。Markdown imports keep their headings.

## [0.3.1] - 2026-10-15

> 打开主窗口时也会检查新版本，发布后更快看到更新提示。
> Checks for updates when you open the main window, so new versions show up sooner.

### 改进 Changed
- 打开主窗口时，如果距离上次检查超过 1 小时，会在后台再查一次新版本。之前只在启动时和每 24 小时查一次，而 App 关掉窗口后一直留在刘海里，很少真正重新启动。
  Also checks for updates when the main window opens (if the last check was over an hour ago).

## [0.3.0] - 2026-10-14

> 可以在 App 里一键更新了，还能随时翻看每个版本改了什么；界面换成黑白配色和新图标。
> One-click in-app updates, a version history, a black-and-white look and a new icon.

### 新增 Added
- App 内一键更新：打开 App 时自动检查新版本，主窗口顶部出现提示；点“立即更新”自动下载、校验、安装并重新打开，稿件和设置都保留。正在提词时不打扰，讲完再提示。
  In-app updates (Sparkle): checks on launch, banner in the main window, one click to download, verify, install and relaunch. Never interrupts while prompting.
- 版本日志：右下角“版本日志”用卡片列出每个版本更新了什么。
  Version history cards in the main window.
- 每个版本用同一张本机签名证书签名：更新后不需要重新允许麦克风和语音识别。
  Stable local code signature, so microphone and speech permissions survive updates.
- 安装包同时支持 Apple 芯片和 Intel。Universal build (Apple silicon + Intel).

### 变更 Changed
- 界面改为黑白配色：主按钮白底黑字，选中、进度条、开关都用黑白灰；语速、导演提示、重点这些状态色保持彩色。
  Black-and-white theme; status colors (pace, cues, emphasis) stay colored.
- 提词时正在读的字是纯白并带一条细下划线，还没读到的字是灰色。
  The word being read is white with a thin underline; upcoming words are gray.
- 新图标：白底，左边是声波，右边变成一行字。New app icon: a sound wave turning into a line of text.

## [0.2.0] - 2026-10-14

> 改名 OpenSpeech，界面更简洁，提词卡片可以随意拖动。
> Renamed to OpenSpeech, a simpler UI, and a prompter card you can drag anywhere.

### 变更 Changed
- 产品改名：OpenPitch → OpenSpeech。首次启动自动迁移旧的稿件库、设置、跟随日志（旧数据保留）。因为应用标识变了，系统会重新询问一次麦克风和语音识别权限。
  Renamed from OpenPitch to OpenSpeech; scripts, settings and logs are migrated on first launch. macOS will ask for microphone and speech permissions again.
- 界面极简化：去掉 5 个位置预设和“刘海灵动岛展开”布局，只保留两种显示样式——玻璃卡片（默认）和字幕胶囊（只显示这一句和下一句，字更大）。
  Minimal UI: removed the 5 placement presets and the expanded-island layout; two display styles remain — glass card (default) and caption capsule.
- 提词卡片可以随意拖动：靠近镜头中线自动吸附，拖动时显示离镜头的角度；拖四个角调整每行字数和行数；双击或点“回到默认位置”复位。位置按屏幕分别记住，两种样式共用位置、各记各的大小。
  Free drag with centerline snap and angle readout; corner resize; double-click / button to reset; position remembered per screen.
- 鼠标放到卡片上时，下方出现控制条：上一行 · 暂停 · 下一行 · 结束。刘海里只留状态点、计时和语速提示。
  Hover controls below the card; the notch shows only status, timer and pace hint.
- 主窗口改为三栏：左稿件列表，中编辑，右边只留 6 项设置（显示样式、字号、共享屏幕时隐藏、开始前倒计时、显示在哪块屏幕、回到默认位置）。跟随日志、测试录音移到“文件 › 开发者选项”。
  Three-column main window with six settings; developer options moved to the File menu.

### 修复 Fixed
- 折行时不再把小数、型号拆开（如 “6.9”、“f/1.48”）。Numbers like “6.9” no longer break across lines.

### 移除 Removed
- 快捷键 ⌥⌘1…⌥⌘5（位置预设）。Hotkeys ⌥⌘1–5 (placement presets).

## [0.1.0] - 2026-10-14

> 第一个公开版本：跟着你的声音走的刘海提词器。
> First public release: a notch teleprompter that follows your voice.

First public release.

### 新增 Added
- 语音跟读：本机语音识别 + 拼音模糊对齐，支持中文、英文、中英混排；多音字、数字两种写法（“2024” / “二零二四”）统一处理。
  Voice-follow: on-device recognition + pinyin-fuzzy alignment for Chinese, English and mixed scripts; polyphones and number forms normalized.
- 稿子专属语言模型：每次开始时用当前稿子给识别器生成专属模型（约 1 秒），并补充识别提示词。合成语音测试中错字率中文降约 23%、英文降约 28%。
  Per-script custom language model for the recognizer (~1 s to prepare). In TTS tests, error rate dropped ~23% (zh) / ~28% (en).
- 两种布局：刘海灵动岛展开；刘海小状态岛 + 镜头下方悬浮稿件卡片（毛玻璃、阅读光带、可拖动调角度）。5 个位置预设 A–E（⌥⌘1…5），预览模式。
  Two layouts (notch island / status island + floating card), 5 placement presets, preview mode, drag to adjust angle.
- 智能匀速模式：按目标语速滚动，停顿时自动停住。Smart constant-speed mode that pauses when you stop talking.
- 稿件库：新建 / 粘贴 / 导入 txt、md、docx、doc、rtf、pdf、html，拖文件到刘海导入；【提示】与 **重点** 标记。
  Script library with import (txt/md/docx/doc/rtf/pdf/html), drag-to-notch, cue and emphasis markup.
- 实时语速提示（偏快 / 正好 / 偏慢）、倒计时、全局快捷键、共享屏幕时隐藏。
  Live speech-rate hint, countdown, global hotkeys, hidden from screen sharing.
- 跟随日志（本机）与评估工具：单元测试、未参与调参的新稿件模拟、真实日志回放（`tools/eval/run.sh`），以及 `--replay`、`--asr-bench`、`--snapshot`。
  Local tracking logs and evaluation tooling (unit tests, held-out simulation, real-log replay).
- 可选“保存测试录音”（默认关闭），用于离线对比识别效果。Optional local audio capture for offline tuning (off by default).

### 跟随规则 Tracking behavior
- 只跟“一路念过来”的前进；自由发挥、跳段时停在原地，用 ⌥⌘↓ / 双指滑动手动翻。
  Only advances when you have read your way there; holds on ad-libs and skips (move manually).
- 识别漏听后能追上：从当前位置到新位置这一路在识别结果里出现过，才追过去。
  Catches up after missed recognition when the path in between was actually spoken.
- 往回只允许十几个字（“刚才那句重说”），需持续确认。Small backtracking only (re-reading the last sentence).
- 预测推进：最多领先 0.6 秒、不越过句末和当前行；重新开口时先走一点。
  Conservative look-ahead (≤0.6 s, never past sentence end or current line), quicker restart after pauses.

### 变更 Changed
- 产品改名：NotchCue → OpenPitch。首次启动自动迁移旧的稿件库、设置、日志（旧数据保留）。
  Renamed from NotchCue to OpenPitch; existing scripts, settings and logs are migrated on first launch.

## 开发历程（0.1.0 之前，未单独发布）Pre-release history

| 轮次 Round | 日期 Date | 内容 Summary |
| --- | --- | --- |
| 原型 Prototype | 2026-10-13 | 刘海灵动岛 UI、语音跟读 / 匀速、稿件导入、快捷键、共享屏幕隐藏。Notch island UI, voice-follow & constant speed, import, hotkeys. |
| 第 2 轮 | 2026-10-13 | 修复短词误跳（误跳率 32% → 0）、预测推进、连续滚动、识别无缝换段、数字 / 多音字、跟随日志与回放。Fixed false jumps on short phrases; prediction, continuous scroll, seamless recognizer handover, logs & replay. |
| 第 3 轮 | 2026-10-13 | 视线位置调研；5 个位置预设、悬浮卡片、预览、拖动调角度、按句意断行。Eye-contact placement research; presets, floating card, preview, phrase-aware line breaks. |
| 第 4 轮 | 2026-10-13 | 修复英文跳过头和抢先换行（局部对齐 + 跳字惩罚，抢先换行 374 → 45 次）；【】可选念；往回保护；看门狗。Fixed English overshoot & early line changes; optional cues; backtracking guard; watchdog. |
| 第 5 轮 | 2026-10-13 | 过拟合检查：新增未参与调参的新稿件模拟器，删除 3 条只对个例有效的规则；识别断句后接上前文；预测不越过当前行。Overfitting audit with held-out simulator; removed 3 case-specific rules; context carry-over; line cap. |
| 第 6 轮 = 0.1.0 | 2026-10-14 | 不自动跳、稿子专属语言模型、重新开口衔接、去掉“近距离反而更难前进”的死区、改名 OpenPitch。No auto-jump, per-script language model, faster restart, dead-zone fix, rename. |
