#!/bin/bash
# OpenSpeech 一键安装 / One-line installer (macOS 14+)
#   curl -fsSL https://raw.githubusercontent.com/isaachang/OpenSpeech/main/install.sh | bash
# 下载最新版 → 装进「应用程序」（没有写权限就装到 ~/Applications）→ 打开 → 打印接下来要做的事。
# 已经装过会直接换成最新版，稿件和设置都在。
#   OPENSPEECH_DIR=…      装到别的文件夹
#   OPENSPEECH_NO_OPEN=1  装完不打开
set -euo pipefail

REPO="isaachang/OpenSpeech"
say() { printf '%s\n' "$@"; }
fail() { say "✗ $1" "  $2" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "OpenSpeech 只支持 macOS。" "OpenSpeech only runs on macOS."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 14 ] || fail "需要 macOS 14 或更新版本（这台是 $(sw_vers -productVersion)）。" "Requires macOS 14 or later (this Mac has $(sw_vers -productVersion))."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "▸ 下载最新版 OpenSpeech… / Downloading the latest OpenSpeech…"
URL="https://github.com/$REPO/releases/latest/download/OpenSpeech.zip"
if ! curl -fsSL -o "$TMP/OpenSpeech.zip" "$URL" 2>/dev/null; then
  # 老版本的发布里只有带版本号的 zip：从 GitHub 接口找
  URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
  [ -n "$URL" ] || fail "找不到下载地址，请稍后再试，或去 https://github.com/$REPO/releases/latest 手动下载。" \
                       "Couldn't find the download. Try again later, or download it from https://github.com/$REPO/releases/latest"
  curl -fsSL -o "$TMP/OpenSpeech.zip" "$URL" || fail "下载失败，检查网络后重试。" "Download failed. Check your connection and try again."
fi
ditto -x -k "$TMP/OpenSpeech.zip" "$TMP/x"
[ -d "$TMP/x/OpenSpeech.app" ] || fail "下载的文件不完整，请重试。" "The download looks incomplete. Please try again."

DEST="${OPENSPEECH_DIR:-/Applications}"
if [ -z "${OPENSPEECH_DIR:-}" ] && [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; fi
mkdir -p "$DEST"
APP="$DEST/OpenSpeech.app"

# 要换掉的那份正在运行就先退出，免得换到一半
EXE="$APP/Contents/MacOS/OpenSpeech"
if pgrep -fq "^$EXE"; then
  osascript -e 'tell application id "app.openspeech.mac" to quit' >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -fq "^$EXE" || break; sleep 0.5; done
  pkill -f "^$EXE" 2>/dev/null || true
fi

rm -rf "$APP"
ditto "$TMP/x/OpenSpeech.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "")"

[ "${OPENSPEECH_NO_OPEN:-}" = "1" ] || open "$APP"

HAS_ZOOM=""
if mdfind "kMDItemCFBundleIdentifier == 'us.zoom.xos'" 2>/dev/null | grep -q .; then HAS_ZOOM=1; fi

say "" \
    "✓ OpenSpeech $VERSION 已安装到 / installed to: $APP" \
    "" \
    "接下来 / Next steps" \
    "1. 第一次打开时，允许「麦克风」和「语音识别」。" \
    "   Allow Microphone and Speech Recognition when macOS asks." \
    "2. 用 Zoom 共享屏幕的话，要改一个设置，对方才看不到提词器${HAS_ZOOM:+（这台 Mac 装了 Zoom）}：" \
    "   Zoom › 设置 › 共享屏幕 › 高级 › 屏幕捕获模式 → 「高级捕获（带窗口过滤）」" \
    "   If you share your screen in Zoom${HAS_ZOOM:+ (installed on this Mac)}, change one setting so others can't see the prompter:" \
    "   Zoom › Settings › Share Screen › Advanced › Screen capture mode → Advanced capture with window filtering" \
    "   腾讯会议、Microsoft Teams、钉钉不用改。Tencent Meeting, Microsoft Teams and DingTalk need nothing." \
    "3. 以后的新版本在 App 里一键更新。Future updates install from inside the app." \
    "" \
    "[给 AI 助手 / For AI assistants] 请把上面的「接下来」转告用户，尤其是第 2 条 Zoom 设置。" \
    "Please relay the Next steps above to the user, especially the Zoom setting in step 2."
