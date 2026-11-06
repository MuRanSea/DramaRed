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

桌面壳**不是**手机底栏 + 竖滑全屏的搬迁，布局说明见 [`docs/desktop-ui.md`](../../docs/desktop-ui.md)。

- **左侧导航 + 顶栏搜索**：首页推荐、剧场、搜索、正在播放、历史、收藏、设置
- **宽屏海报网格**：首页 / 剧场 / 搜索 / 收藏；点海报进入播放页
- **播放页**：左侧 9:16 预览框 + 右侧选集 / 清晰度 / 倍速 / 自动连播 / 定时停 / 收藏
- **预加载**：播放后预先请求下一集 playback URL
- **历史续播**：点历史项按上次进度继续
- **后台听**：隐藏到托盘（或仅 Hide），音频继续；`Ctrl+H`
- **快捷键**：空格播放暂停，↑↓ 切集，←→ 快进 5 秒，M 静音，`Ctrl+F` 搜索，Esc 离开播放页

画面优先在 **独立 mpv 窗口**（`force-window=yes`，需 `DISPLAY` 或 Windows 上可选 `libmpv-2.dll`）。无显示时见下方 headless。

若与 `DramaRed.UI` 同目录放有 `drama-daemon`（Windows 为 `drama-daemon.exe`），主窗口启动时会在 daemon 未响应时自动拉起。

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


## Windows 发布包

在 Linux box 上交叉编译（不需要 Windows 宿主机）：

```sh
./scripts/package-windows.sh
# → dist/DramaRed-desktop-win-x64.zip
```

解压后双击 `DramaRed.UI.exe`。程序会尝试拉起同目录的 `drama-daemon.exe`。

- 需要 .NET 运行时？本脚本默认 `--self-contained true`，不需要另装。
- 要看到画面：把 `libmpv-2.dll`（以及其依赖）放到 exe 旁；没有 DLL 时仍可浏览、搜索，播放会提示缺少后端。
- 不要把 daemon 端口暴露到公网。


## 测试

```bash
# Headless UI + 单元（Avalonia.Headless.XUnit）
dotnet test apps/desktop/ui.Tests/DramaRed.UI.Tests.csproj -c Release

# 全链路 e2e：上述测试 + daemon API + xvfb GUI + Windows zip/libmpv 静态检查
./scripts/desktop-e2e.sh
```
