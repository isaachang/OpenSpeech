# Changelog / 版本日志

格式参考 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循 [语义化版本](https://semver.org/)。
Format based on Keep a Changelog; versions follow Semantic Versioning.

## [0.2.0] - 2026-10-14

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

第一个公开版本。First public release.

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
