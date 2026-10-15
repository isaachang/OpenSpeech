#!/bin/bash
# 跟随算法评估：单元测试 + 新稿件模拟（防过拟合）+ 真实日志回放
# 用法：tools/eval/run.sh [sim 变体，如 -carry / -predict / -immediate / -linecap]
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=$(mktemp -d)
SRC=(); for f in Sources/*.swift; do [[ "$f" != *main.swift ]] && SRC+=("$f"); done
# 整个 App 的源码里有自动更新（Sparkle），模拟 / 回放程序也要能链接到它
tools/fetch-sparkle.sh
SPARKLE=(-F vendor/Sparkle -framework Sparkle -Xlinker -rpath -Xlinker "$PWD/vendor/Sparkle")
echo "▸ 单元测试（固定场景）"
swiftc -O -swift-version 5 Sources/ScriptParser.swift Sources/Tracker.swift tools/eval/unit/main.swift -o "$OUT/unit"
"$OUT/unit" tools/eval/unit/sample-script.txt | tail -3
echo "▸ 新稿件模拟（4 篇未参与调参的中英文稿 × 8 个随机种子；含跳段、自由发挥、复述前文、改词、重说、识别错字、断句碎片）"
swiftc -O -swift-version 5 "${SPARKLE[@]}" "${SRC[@]}" tools/eval/common/Harness.swift tools/eval/sim/main.swift -o "$OUT/sim"
"$OUT/sim" "${1:-all}"
if ls "$HOME/Library/Application Support/OpenSpeech/logs/"*.jsonl >/dev/null 2>&1; then
  echo "▸ 真实日志回放（本机跟随日志）"
  swiftc -O -swift-version 5 "${SPARKLE[@]}" "${SRC[@]}" tools/eval/common/Harness.swift tools/eval/common/Oracle.swift tools/eval/replay/main.swift -o "$OUT/replay"
  "$OUT/replay" | tail -2
fi
rm -rf "$OUT"
