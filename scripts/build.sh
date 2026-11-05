#!/usr/bin/env bash
# 构建 DeepSeek for BlackBerry 10
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${BBNDK_IMAGE:-docker.io/accupara/bbndk}
ENV_SH=/home/admin/bin/bbndk/bbndk-env_10_3_1_995.sh

echo "[*] 使用镜像 $IMAGE"
podman run --rm --user 0 -v "$PWD:/work:Z" -w /work "$IMAGE" bash -lc "
  set -e
  source $ENV_SH >/dev/null 2>&1
  rm -f deepseek deepseek.bar Makefile main.o main.moc qrc_resources.cpp
  qmake deepseek.pro >/dev/null
  make 2>&1 | grep -viE '^(qcc|/home/admin|rcc)' || true
  mkdir -p dist
  rm -f dist/deepseek.bar
  blackberry-nativepackager -package dist/deepseek.bar -devMode \
    bar-descriptor.xml -C . deepseek icon.png -e icon.png icon.png
"
echo "[+] 完成：dist/deepseek.bar"
