# DramaRed Desktop（跨平台）

Avalonia UI（Linux / Windows / macOS）↔ Go daemon ↔ libmpv。

目录历史上曾叫 `apps/windows`；现为跨平台 desktop，不绑定 Win32。

## 技术

| 组件 | 说明 |
|---|---|
| UI | Avalonia **12.1.2**，`TargetFramework=net10.0`，RIDs: `linux-x64;win-x64;osx-x64;osx-arm64` |
| SDK | .NET **10.0.403**（box 已装） |
| daemon | Go + openhongguo `v0.2.0`，本机 HTTP `127.0.0.1:17890` |
| 播放 | `IMediaPlayer`；`LibMpvMediaPlayer` 真正 `OpenAsync`；失败回退 `NullMediaPlayer` |

## 启动

```sh
# 终端 1
cd apps/desktop/daemon
go run ./cmd/drama-daemon
# 或: go build -o drama-daemon ./cmd/drama-daemon && ./drama-daemon -data ./data

# 终端 2
cd apps/desktop/ui
dotnet run -c Release -r linux-x64   # 或 win-x64 / osx-arm64
```

### UI 能力

- **书城 / 搜索**：`GET /api/v1/discover`、`/search`，列表可选中加载分集
- **分集**：双击播放 → daemon playback → libmpv `loadfile`
- **播放控件**：暂停/继续/停止、倍速、自动连播、定时停止
- **历史 / 收藏**：读写 daemon JSON；历史双击续播（seek）
- **托盘 / 隐藏**：无托盘环境则仅 `Hide()`，音频继续

画面优先在 **独立 mpv 窗口**（`force-window=yes`，需 `DISPLAY`）。无显示时见下方 headless。

## 播放后端探测

`MediaPlayerFactory` / `LibMpvMediaPlayer.TryCreate`：

| OS | 候选 |
|---|---|
| Linux | `libmpv.so.2`、`/usr/lib/x86_64-linux-gnu/libmpv.so.2` |
| macOS | Homebrew / `/usr/local` dylib |
| Windows | 可执行文件旁可选 `libmpv-2.dll` / `mpv-2.dll`（**非硬依赖**） |

受保护流：best-effort 设置 `demuxer-lavf-o=decryption_key=…`（来自 daemon `contentKey`）。

## 构建

```sh
dotnet build -c Release -r linux-x64 --self-contained false
# → bin/Release/net10.0/linux-x64/DramaRed.UI.dll
```

## libmpv 冒烟（无 Avalonia）

```sh
cd apps/desktop/tools/mpv-smoke
dotnet run -c Release
# 可选: dotnet run -c Release -- /path/to/local.mp4
```

## Headless / 无显示

| 场景 | 做法 |
|---|---|
| 有 `DISPLAY`（box 桌面 / 本机） | 正常 `dotnet run`；mpv 外开窗口 |
| CI / SSH 无显示 | `vo=null`（无 DISPLAY 时自动）；或 `xvfb-run -a dotnet run …` 仅验证进程不崩 |
| 仅验证 daemon | `curl` `/health`、`/api/v1/*` 即可，不必启 UI |

## 合规

仅学习研究、禁止商业；见根 README。
