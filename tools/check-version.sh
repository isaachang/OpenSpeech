#!/bin/bash
# 上传前检查：VERSION、两个 README 的版本号、CHANGELOG 最新一条是否一致
set -euo pipefail
cd "$(dirname "$0")/.."
V="$(tr -d '[:space:]' < VERSION)"
ok=1
for f in README.md README.zh-CN.md; do
  grep -q "badge/version-$V-" "$f" || { echo "✗ $f 顶部版本号不是 $V"; ok=0; }
done
TOP="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')"
[ "$TOP" = "$V" ] || { echo "✗ CHANGELOG.md 最新一条是 $TOP，不是 $V"; ok=0; }
[ $ok = 1 ] && echo "✓ 版本号一致：v$V" || exit 1
