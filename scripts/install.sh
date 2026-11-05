#!/usr/bin/env bash
# 安装到已 root 的 BB10 设备
set -euo pipefail
cd "$(dirname "$0")/.."

DEV=${BB10_HOST:-root@169.254.0.1}
BAR=${1:-dist/deepseek.bar}
[ -f "$BAR" ] || { echo "找不到 $BAR，请先运行 scripts/build.sh"; exit 1; }

ID=$(unzip -p "$BAR" META-INF/MANIFEST.MF | grep '^Package-Id:' | cut -d' ' -f2 | tr -d '\r')
VER=$(unzip -p "$BAR" META-INF/MANIFEST.MF | grep '^Package-Version:' | cut -d' ' -f2 | tr -d '\r')
NAME=$(unzip -p "$BAR" META-INF/MANIFEST.MF | grep '^Package-Name:' | cut -d' ' -f2 | tr -d '\r')

TMP=$(mktemp -d)
printf 'Package-Id: %s\nPackage-Name: %s\nPackage-Version: %s\n' "$ID" "$NAME" "$VER" > "$TMP/MANIFEST"
cp "$BAR" "$TMP/pkg.bar"
( cd "$TMP" && zip -q install.zip MANIFEST pkg.bar )

echo "[*] 推送到 $DEV"
cat "$TMP/install.zip" | ssh "$DEV" "cat > /accounts/1000/shared/downloads/deepseek-install.zip"
echo "[*] 安装"
ssh "$DEV" "/var/rootdata/installer /accounts/1000/shared/downloads/deepseek-install.zip"
rm -rf "$TMP"
echo "[+] 完成，请在手机上打开 DeepSeek"
