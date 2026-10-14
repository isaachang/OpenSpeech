#!/bin/bash
# 构建 OpenPitch.app（只需要 Xcode Command Line Tools，不需要完整 Xcode）
set -euo pipefail
cd "$(dirname "$0")"

APP="build/OpenPitch.app"
ARCH="$(uname -m)"
VERSION="$(cat VERSION | tr -d '[:space:]')"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ 编译 Swift ($ARCH)…"
swiftc -O -swift-version 5 \
  -target "$ARCH-apple-macos14.0" \
  -o "$APP/Contents/MacOS/OpenPitch" \
  Sources/*.swift

echo "▸ 生成图标…"
"$APP/Contents/MacOS/OpenPitch" --export-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.openpitch.mac</string>
  <key>CFBundleName</key><string>OpenPitch</string>
  <key>CFBundleDisplayName</key><string>OpenPitch</string>
  <key>CFBundleExecutable</key><string>OpenPitch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>OpenPitch 需要听你说话，才能让提词跟上你的语速、在你停顿时自动等你。</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>OpenPitch 用语音识别判断你讲到了稿子的哪里（优先在本机完成）。</string>
  <key>NSHumanReadableCopyright</key><string>OpenPitch · MIT License</string>
</dict>
</plist>
PLIST

echo "▸ 签名（ad-hoc）…"
codesign --force --deep --sign - "$APP" >/dev/null

echo "✓ 完成：$APP（v$VERSION）"
echo "  运行：open $APP"
