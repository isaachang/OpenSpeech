#!/bin/bash
# 一次性准备发版用的两把钥匙（都放在 ~/.openspeech-signing，不进仓库，请备份这个文件夹）：
#   1. 本机代码签名证书「OpenSpeech Local Signing」：每个版本用同一张证书签名，
#      macOS 才认得出是同一个 App，麦克风 / 语音识别授权不会因为更新而丢。
#   2. Sparkle 更新签名私钥：给每个安装包签名，App 只装签名对得上的更新。
# 已经准备过的会跳过。
set -euo pipefail
cd "$(dirname "$0")/.."

DIR="$HOME/.openspeech-signing"
KC="$DIR/signing.keychain-db"
PW_FILE="$DIR/keychain-password"
ED_KEY="$DIR/sparkle_ed25519_private_key"
PUB_FILE="tools/sparkle-public-key.txt"
NAME="OpenSpeech Local Signing"

mkdir -p "$DIR" && chmod 700 "$DIR"

if [ ! -f "$KC" ]; then
  echo "▸ 生成本机签名证书…"
  /usr/bin/openssl rand -hex 24 > "$PW_FILE" && chmod 600 "$PW_FILE"
  PW="$(cat "$PW_FILE")"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$tmp/cert.cnf" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$NAME" \
    -out "$tmp/cert.p12" -passout pass:"$PW" 2>/dev/null
  security create-keychain -p "$PW" "$KC"
  security set-keychain-settings "$KC"            # 不自动上锁
  security unlock-keychain -p "$PW" "$KC"
  security import "$tmp/cert.p12" -k "$KC" -P "$PW" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple: -s -k "$PW" "$KC" >/dev/null
  cp "$tmp/cert.pem" "$DIR/signing-cert.pem"
  echo "✓ 证书：$NAME"
fi

if [ ! -f "$ED_KEY" ]; then
  echo "▸ 生成 Sparkle 更新签名私钥…"
  tools/fetch-sparkle.sh
  vendor/Sparkle/bin/generate_keys --account app.openspeech.mac >/dev/null
  vendor/Sparkle/bin/generate_keys --account app.openspeech.mac -x "$ED_KEY"
  chmod 600 "$ED_KEY"
  vendor/Sparkle/bin/generate_keys --account app.openspeech.mac -p > "$PUB_FILE"
  echo "✓ 公钥写入 $PUB_FILE（这个可以公开，要提交到仓库）"
fi

# codesign 只在钥匙串搜索列表里找证书：把这个独立钥匙串加进去（不改动登录钥匙串本身）
if ! security list-keychains -d user | grep -q "$KC"; then
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KC"
fi

echo "✓ 签名环境就绪。备份 $DIR 这个文件夹：丢了私钥，已经装好的用户就收不到更新了。"
