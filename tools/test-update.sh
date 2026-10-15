#!/bin/bash
# 在本机把“旧版本 → 新版本”的自动更新完整跑一遍，不碰 GitHub：
# 编一个旧版本和一个新版本，本机起一个小服务器当更新服务器，打开旧版本，看它能不能自己更新成新版本。
#   tools/test-update.sh            自动点“立即更新”，检查是否更新成功
#   tools/test-update.sh --manual   只搭好环境、打开旧版本，自己点按钮试；按回车结束
set -euo pipefail
cd "$(dirname "$0")/.."

OLD="$(tr -d '[:space:]' < VERSION)"
IFS=. read -r A B C <<< "$OLD"
NEW="$A.$B.$((C + 1))"
PORT=8799
while lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do PORT=$((PORT + 1)); done
T="$PWD/dist/update-test"
FEED="http://127.0.0.1:$PORT/appcast.xml"
APP="$T/app/OpenSpeech.app"
rm -rf "$T" && mkdir -p "$T/feed" "$T/app"

cat > "$T/notes.md" <<NOTES
## [$NEW] - $(date +%F)

> 本地测试用的新版本，用来确认自动更新能跑通。

### 新增 Added
- 这是一条测试更新：看到它说明更新说明能正常显示。
### 修复 Fixed
- 更新后稿件和设置都还在。
NOTES

echo "━━ 1/3 编译新版本 $NEW（放到本机更新服务器）"
OPENSPEECH_VERSION="$NEW" FEED_URL="$FEED" RELEASE_NOTES_FILE="$T/notes.md" \
  tools/release.sh --local "$T/feed" "http://127.0.0.1:$PORT" 2>&1 | grep -E "✓|✗|error:"
echo "━━ 2/3 编译旧版本 $OLD"
OPENSPEECH_VERSION="$OLD" FEED_URL="$FEED" ./build.sh 2>&1 | grep -E "✓|✗|error:"
ditto build/OpenSpeech.app "$APP"

# 测试 App 和正式 App 是同一个应用标识，结束后把“上次运行的版本”改回去，免得影响正式 App 的“已更新”提示
PREV_RUN="$(defaults read app.openspeech.mac lastRunVersion 2>/dev/null || true)"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$T/feed" > "$T/server.log" 2>&1 &
SERVER=$!
cleanup() {
  kill $SERVER 2>/dev/null || true; wait $SERVER 2>/dev/null || true
  pkill -f "$APP/Contents/MacOS/OpenSpeech" 2>/dev/null || true
  if [ -n "$PREV_RUN" ]; then defaults write app.openspeech.mac lastRunVersion "$PREV_RUN"; else defaults delete app.openspeech.mac lastRunVersion 2>/dev/null || true; fi
}
trap cleanup EXIT
sleep 1

echo "━━ 3/3 打开旧版本 $OLD：$APP"
if [ "${1:-}" = "--manual" ]; then
  open "$APP"
  echo "   大约 3 秒后主窗口顶部会出现「OpenSpeech $NEW 可以更新了」，点「立即更新」试试。"
  read -r -p "   试完按回车结束（会关掉测试 App 和服务器）… "
  exit 0
fi

OPENSPEECH_TEST_AUTO_INSTALL=1 "$APP/Contents/MacOS/OpenSpeech" >/dev/null 2>&1 &
ver() { /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || true; }
for i in $(seq 1 90); do
  if [ "$(ver)" = "$NEW" ] && pgrep -f "$APP/Contents/MacOS/OpenSpeech" >/dev/null; then
    echo "✓ ${i} 秒后更新完成并重新打开：$OLD → $(ver)"
    grep -oE '"GET [^"]+" [0-9]+' "$T/server.log" | sed 's/^/   服务器收到 /'
    codesign --verify --deep --strict "$APP" && echo "✓ 新版本签名有效"
    echo "   签名身份：$(codesign -d -r- "$APP" 2>&1 | tail -1 | sed 's/.*certificate leaf = //')"
    sleep 4
    exit 0
  fi
  sleep 1
done
echo "✗ 90 秒内没有更新成功。当前版本：$(ver)"
cat "$T/server.log"
exit 1
