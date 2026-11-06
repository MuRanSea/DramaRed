#!/usr/bin/env bash
# Cross-compile a runnable Windows x64 zip from Linux / macOS / Windows.
# Bundles LGPL libmpv-2.dll (downloaded from official mpv git-release assets).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/dist/DramaRed-desktop-win-x64"
ZIP="${ROOT}/dist/DramaRed-desktop-win-x64.zip"
CONFIG="${CONFIG:-Release}"
CACHE="${ROOT}/.cache"
LIBMPV_DIR="${ROOT}/third_party/libmpv-win-x64"
# Pinned official LGPL build (dynamic libmpv-2.dll). Update URL when bumping.
LIBMPV_URL="${LIBMPV_URL:-https://github.com/mpv-player/mpv/releases/download/git-release/libmpv-v0.42.0-dev-g902818753-42055904469-x86_64-w64-mingw32-lgpl.zip}"
LIBMPV_ZIP="${CACHE}/libmpv-x86_64-lgpl.zip"

rm -rf "${OUT}"
mkdir -p "${OUT}" "${CACHE}" "${LIBMPV_DIR}"

echo "==> publish Avalonia UI (win-x64, self-contained)"
dotnet publish "${ROOT}/apps/desktop/ui/DramaRed.UI.csproj" \
  -c "${CONFIG}" \
  -r win-x64 \
  --self-contained true \
  -p:PublishReadyToRun=false \
  -p:DebugType=portable \
  -o "${OUT}"

echo "==> cross-compile Go daemon (windows/amd64)"
(
  cd "${ROOT}/apps/desktop/daemon"
  GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o "${OUT}/drama-daemon.exe" ./cmd/drama-daemon
)

echo "==> fetch / extract LGPL libmpv-2.dll"
if [[ ! -f "${LIBMPV_DIR}/libmpv-2.dll" ]]; then
  if [[ ! -f "${LIBMPV_ZIP}" ]]; then
    echo "    downloading ${LIBMPV_URL}"
    curl -L --fail --retry 3 -o "${LIBMPV_ZIP}.partial" "${LIBMPV_URL}"
    mv "${LIBMPV_ZIP}.partial" "${LIBMPV_ZIP}"
  fi
  python3 - << PY
import zipfile, shutil, os
zf = zipfile.ZipFile("${LIBMPV_ZIP}")
out = "${LIBMPV_DIR}"
os.makedirs(out, exist_ok=True)
for name in zf.namelist():
    base = os.path.basename(name)
    if base.lower() in ("libmpv-2.dll", "license.lgpl", "copying.lgpl", "copying"):
        with zf.open(name) as src, open(os.path.join(out, base if base.lower() != "copying" else "LICENSE.LGPL"), "wb") as dst:
            shutil.copyfileobj(src, dst)
            print("extracted", base)
if not os.path.exists(os.path.join(out, "libmpv-2.dll")):
    raise SystemExit("libmpv-2.dll missing from archive")
PY
fi
cp -f "${LIBMPV_DIR}/libmpv-2.dll" "${OUT}/libmpv-2.dll"
if [[ -f "${LIBMPV_DIR}/LICENSE.LGPL" ]]; then
  mkdir -p "${OUT}/THIRD_PARTY"
  cp -f "${LIBMPV_DIR}/LICENSE.LGPL" "${OUT}/THIRD_PARTY/libmpv-LICENSE.LGPL"
fi
if [[ -f "${LIBMPV_DIR}/README.txt" ]]; then
  cp -f "${LIBMPV_DIR}/README.txt" "${OUT}/THIRD_PARTY/libmpv-README.txt"
fi

cat > "${OUT}/README.txt" << 'TXT'
DramaRed Desktop (Windows x64) — v0.2
=====================================

1. 解压到任意目录（路径尽量短、少特殊字符）。
2. 双击 DramaRed.UI.exe（或 start.bat）。
   程序会自动拉起同目录的 drama-daemon.exe（仅监听 127.0.0.1:17890）。
3. 本包已捆绑 LGPL 版 libmpv-2.dll，播放时会弹出独立竖屏窗口。
   许可见 THIRD_PARTY/ 目录。
4. 若首页提示上游繁忙/网关错误：点「重新加载」或「立即重试」。
   短剧内容来自上游接口，偶发 502 时重试即可。
5. 不做下载，仅在线播放。个人学习 / 自用，禁止商业用途。

快捷键
  空格          播放 / 暂停
  ↑ / PageUp    上一集
  ↓ / PageDown  下一集
  ← / →         快退 / 快进 5 秒
  M             静音
  Ctrl+F        聚焦搜索
  Ctrl+H        隐藏窗口继续听
  Esc           离开播放页
TXT

cat > "${OUT}/start.bat" << 'BAT'
@echo off
cd /d "%~dp0"
start "" DramaRed.UI.exe
BAT

rm -f "${ZIP}"
(
  cd "${ROOT}/dist"
  python3 - << 'PY'
import os, zipfile
root = "DramaRed-desktop-win-x64"
zip_path = "DramaRed-desktop-win-x64.zip"
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for dirpath, _, files in os.walk(root):
        for name in files:
            full = os.path.join(dirpath, name)
            zf.write(full, full)
print("wrote", zip_path)
PY
)

echo "==> done: ${ZIP}"
ls -lh "${ZIP}" "${OUT}/DramaRed.UI.exe" "${OUT}/drama-daemon.exe" "${OUT}/libmpv-2.dll"
