#!/bin/bash
# 下载自动更新框架 Sparkle（固定版本 + 校验 SHA-256）到 vendor/Sparkle。已经有了就跳过。
set -euo pipefail
cd "$(dirname "$0")/.."

VER="2.10.0"
SHA="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"
DEST="vendor/Sparkle"

[ -f "$DEST/.version" ] && [ "$(cat "$DEST/.version")" = "$VER" ] && exit 0

echo "▸ 下载 Sparkle $VER…"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/sparkle.tar.xz" "https://github.com/sparkle-project/Sparkle/releases/download/$VER/Sparkle-$VER.tar.xz"
echo "$SHA  $tmp/sparkle.tar.xz" | shasum -a 256 -c - >/dev/null || { echo "✗ Sparkle 安装包校验失败"; exit 1; }
rm -rf "$DEST" && mkdir -p "$DEST"
tar -xJf "$tmp/sparkle.tar.xz" -C "$DEST"
echo "$VER" > "$DEST/.version"
echo "✓ Sparkle $VER → $DEST"
