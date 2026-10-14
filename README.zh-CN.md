# OpenPitch

![version](https://img.shields.io/badge/version-0.1.0-blue) ![platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![license](https://img.shields.io/badge/license-MIT-green)

[English](README.md) · [版本日志](CHANGELOG.md)

一个住在 MacBook 刘海里、**会跟着你说话走**的开源提词器。
适合开会、学生上台讲 presentation、录屏讲解：需要看着镜头念稿的场合都能用。

> **当前状态：早期版本（v0.1.0）。** 核心的语音跟随已经可用，界面还在重新设计。

## 功能

- **跟着你的声音走**：本机语音识别实时判断你讲到哪，支持中文、英文、中英混排。
- **自由发挥不乱跳**：你脱稿时它停住等你；只有你真的一路念过来了，它才往前走。
- **识别器认识你的稿子**：每篇稿子都会自动生成一个专属语言模型交给识别器（macOS 14+），人名、专有名词、中英混排的术语更不容易听错。
- **按看镜头的角度摆放**：刘海里一个小状态岛 + 镜头下方几度的悬浮稿件卡片，5 个位置预设，可以直接拖动调整。
- **智能匀速模式**：按你的语速滚动，你一停嘴它就停。
- 共享屏幕时隐藏（大多数软件中有效）、全局快捷键、导入 txt / md / docx / pdf / rtf，也可以把文件直接拖到刘海上。

## 运行环境

- macOS 14 及以上（Apple 芯片或 Intel）
- Xcode 命令行工具（`xcode-select --install`）

## 编译和运行

```bash
./build.sh
open build/OpenPitch.app
```

第一次使用时允许**麦克风**和**语音识别**权限。目前用的是本地签名，每次重新编译后系统可能会再问一次。

## 快捷键

| 键 | 作用 |
| --- | --- |
| `⌥⌘P` | 开始 / 暂停 / 继续 |
| `⌥⌘↑` `⌥⌘↓` | 上一行 / 下一行（也可以在提词上双指滑动） |
| `⌥⌘←` `⌥⌘→` | 匀速模式下减速 / 加速 |
| `⌥⌘1`…`⌥⌘5` | 切换位置预设 |
| `⌥⌘.` | 结束 |

稿件标记：`【…】` / `[…]` 写表演提示（念不念都行），`**…**` 标出要重读的词。

## 隐私

所有处理都在你的 Mac 上完成。跟随日志（用于调优）只存在 `~/Library/Application Support/OpenPitch/logs/`，可以在设置里关掉。

## 开发

```bash
tools/eval/run.sh   # 单元测试 + 新稿件模拟 + 本机真实日志回放
```

改动跟随算法时，必须在"没见过的新稿件模拟"和"真实日志回放"两份数据上都没有变差，不为单个案例加规则。

**发布新版本：** 改 `VERSION`、两个 README 顶部的版本号，在 `CHANGELOG.md` 里加一条记录，然后运行 `tools/check-version.sh` 检查。

`docs/` 里是开发过程中的调研记录（当时产品还叫 NotchCue）。

## 许可证

[MIT](LICENSE)
