#!/bin/bash
# 发版：编译（Apple 芯片 + Intel）→ 打 zip → 用 Sparkle 私钥签名 → 生成 appcast.xml → 发到 GitHub Releases。
#   tools/release.sh                         正式发布 VERSION 里的版本（代码要先提交并推送）
#   tools/release.sh --local DIR BASE_URL    只在 DIR 里生成 zip + appcast.xml，不上传（tools/test-update.sh 用）
# 更新说明取自 CHANGELOG.md 里这个版本的那一段；可以用 RELEASE_NOTES_FILE 指定别的文件。
set -euo pipefail
cd "$(dirname "$0")/.."

MODE=publish
if [ "${1:-}" = "--local" ]; then
  MODE=local; OUT="$2"; BASE_URL="$3"
fi

V="${OPENSPEECH_VERSION:-$(tr -d '[:space:]' < VERSION)}"
REPO="isaachang/OpenSpeech"
ED_KEY="$HOME/.openspeech-signing/sparkle_ed25519_private_key"
[ -f "$ED_KEY" ] || { echo "✗ 没有 Sparkle 私钥，先运行 tools/setup-signing.sh"; exit 1; }

if [ $MODE = publish ]; then
  tools/check-version.sh
  OUT="dist"
  BASE_URL="https://github.com/$REPO/releases/download/v$V"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "✗ 还有没提交的改动"; exit 1; }
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "✗ 本地 main 和 GitHub 上不一致，先 push"; exit 1; }
  gh release view "v$V" --repo "$REPO" >/dev/null 2>&1 && { echo "✗ v$V 已经发布过了，先改 VERSION"; exit 1; }
fi

# 这个版本的更新说明：CHANGELOG.md 里从 “## [V]” 到下一个 “## ” 之前
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
if [ -n "${RELEASE_NOTES_FILE:-}" ]; then
  cp "$RELEASE_NOTES_FILE" "$NOTES"
else
  awk -v v="$V" 'index($0, "## [" v "]") == 1 { on = 1; print; next } on && /^## / { exit } on { print }' CHANGELOG.md > "$NOTES"
fi
[ -s "$NOTES" ] || { echo "✗ CHANGELOG.md 里找不到 [$V] 这一段"; exit 1; }

UNIVERSAL=1 ./build.sh
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' build/OpenSpeech.app/Contents/Info.plist)"

mkdir -p "$OUT"
ZIP="OpenSpeech-$V.zip"
rm -f "$OUT/$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/OpenSpeech.app "$OUT/$ZIP"
SIG="$(vendor/Sparkle/bin/sign_update --ed-key-file "$ED_KEY" "$OUT/$ZIP")"

cat > "$OUT/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>OpenSpeech</title>
    <item>
      <title>OpenSpeech $V</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$V</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description sparkle:format="plain-text"><![CDATA[
$(cat "$NOTES")
]]></description>
      <enclosure url="$BASE_URL/$ZIP" $SIG type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "✓ $OUT/$ZIP（$(du -h "$OUT/$ZIP" | cut -f1 | tr -d ' ')）+ $OUT/appcast.xml"

if [ $MODE = publish ]; then
  echo "▸ 发布到 GitHub Releases…"
  gh release create "v$V" "$OUT/$ZIP" "$OUT/appcast.xml" --repo "$REPO" \
    --title "OpenSpeech $V" --notes-file "$NOTES" --latest
  echo "✓ 已发布：https://github.com/$REPO/releases/tag/v$V"
fi
