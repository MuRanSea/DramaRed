#!/usr/bin/env bash
# Cross-compile a runnable Windows x64 zip from Linux / macOS / Windows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/dist/DramaRed-desktop-win-x64"
ZIP="${ROOT}/dist/DramaRed-desktop-win-x64.zip"
CONFIG="${CONFIG:-Release}"

rm -rf "${OUT}"
mkdir -p "${OUT}"

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

cat > "${OUT}/README.txt" << 'TXT'
DramaRed Desktop (Windows x64)
==============================

1. 解压到任意目录（路径最好不要有极长中文，以免个别杀毒软件误报）。
2. 双击 DramaRed.UI.exe。
   若本机还没运行 daemon，程序会自动启动同目录的 drama-daemon.exe
   （监听 127.0.0.1:17890，历史/收藏写在 daemon 的 data 目录）。
3. 可选：将 libmpv-2.dll 放到本目录以显示独立播放窗口。
   没有该 DLL 时仍可浏览、搜索、选剧；打开播放会提示缺少后端。
4. 本项目不做下载，仅在线播放。个人学习 / 自用，禁止商业用途。

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
ls -lh "${ZIP}" "${OUT}/DramaRed.UI.exe" "${OUT}/drama-daemon.exe"
