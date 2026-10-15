#!/bin/bash
# 构建 OpenSpeech.app（只需要 Xcode Command Line Tools，不需要完整 Xcode）
#   ./build.sh                 本机架构，日常开发
#   UNIVERSAL=1 ./build.sh     同时支持 Apple 芯片和 Intel（发版用，tools/release.sh 会自动加）
# 可选环境变量（本地测试更新流程用）：
#   OPENSPEECH_VERSION=0.3.1   覆盖 VERSION 文件里的版本号
#   FEED_URL=http://…          覆盖更新清单地址
set -euo pipefail
cd "$(dirname "$0")"

APP="build/OpenSpeech.app"
VERSION="${OPENSPEECH_VERSION:-$(tr -d '[:space:]' < VERSION)}"
FEED_URL="${FEED_URL:-https://github.com/isaachang/OpenSpeech/releases/latest/download/appcast.xml}"
SIGN_ID="OpenSpeech Local Signing"
SIGN_KC="$HOME/.openspeech-signing/signing.keychain-db"

# Sparkle 按 CFBundleVersion 判断新旧：0.3.0 → 300，1.2.3 → 10203
IFS=. read -r MAJ MIN PAT <<< "$VERSION"
BUILD_NUMBER=$(( 10#$MAJ * 10000 + 10#$MIN * 100 + 10#${PAT%%[!0-9]*} ))

tools/fetch-sparkle.sh
SPARKLE="vendor/Sparkle/Sparkle.framework"
PUBKEY="$(tr -d '[:space:]' < tools/sparkle-public-key.txt)"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

compile() {
  swiftc -O -swift-version 5 \
    -target "$1-apple-macos14.0" \
    -F vendor/Sparkle -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -o "$2" \
    Sources/*.swift
}
if [ "${UNIVERSAL:-0}" = 1 ]; then
  echo "▸ 编译 Swift（arm64 + x86_64）…"
  compile arm64 build/OpenSpeech-arm64
  compile x86_64 build/OpenSpeech-x86_64
  lipo -create build/OpenSpeech-arm64 build/OpenSpeech-x86_64 -output "$APP/Contents/MacOS/OpenSpeech"
  rm build/OpenSpeech-arm64 build/OpenSpeech-x86_64
else
  echo "▸ 编译 Swift ($(uname -m))…"
  compile "$(uname -m)" "$APP/Contents/MacOS/OpenSpeech"
fi

# 只是普通（非沙盒）App，用不到 Sparkle 的 XPC 服务
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"

echo "▸ 生成图标…"
"$APP/Contents/MacOS/OpenSpeech" --export-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.openspeech.mac</string>
  <key>CFBundleName</key><string>OpenSpeech</string>
  <key>CFBundleDisplayName</key><string>OpenSpeech</string>
  <key>CFBundleExecutable</key><string>OpenSpeech</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>OpenSpeech 需要听你说话，才能让提词跟上你的语速、在你停顿时自动等你。</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>OpenSpeech 用语音识别判断你讲到了稿子的哪里（优先在本机完成）。</string>
  <key>NSHumanReadableCopyright</key><string>OpenSpeech · MIT License</string>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$PUBKEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUAllowsAutomaticUpdates</key><false/>
</dict>
</plist>
PLIST

# 有本机签名证书（tools/setup-signing.sh）就用它签：每个版本签名身份一致，更新后不用重新授权。
# 没有（比如别人自己编译）就退回 ad-hoc 签名。
if [ -f "$SIGN_KC" ] && security find-identity -p codesigning "$SIGN_KC" | grep -q "$SIGN_ID"; then
  echo "▸ 签名（$SIGN_ID）…"
  security unlock-keychain -p "$(cat "$HOME/.openspeech-signing/keychain-password")" "$SIGN_KC"
  SIGN=(codesign --force --keychain "$SIGN_KC" --sign "$SIGN_ID")
else
  echo "▸ 签名（ad-hoc）…"
  SIGN=(codesign --force --sign -)
fi
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" "$FW/Autoupdate" >/dev/null
"${SIGN[@]}" "$FW/Updater.app" >/dev/null
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework" >/dev/null
"${SIGN[@]}" "$APP" >/dev/null

echo "✓ 完成：$APP（v$VERSION，build $BUILD_NUMBER）"
echo "  运行：open $APP"
