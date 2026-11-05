# DramaRed Desktop（跨平台）

Avalonia UI（Linux / Windows / macOS）↔ Go daemon ↔ libmpv。

目录历史上曾叫 `apps/windows`；现为跨平台 desktop，不绑定 Win32。

## 技术

| 组件 | 说明 |
|---|---|
| UI | Avalonia **12.1.2**，`TargetFramework=net10.0`，RIDs: `linux-x64;win-x64;osx-x64;osx-arm64` |
| SDK | .NET **10.0.403**（box 已装） |
| daemon | Go + openhongguo `v0.2.0`，本机 HTTP `127.0.0.1:17890` |
| 播放 | `IMediaPlayer` 抽象；Linux/macOS 探测系统 libmpv；Windows 可选 `libmpv-2.dll` |

## 启动

```sh
# 终端 1
cd apps/desktop/daemon
go run ./cmd/drama-daemon

# 终端 2
cd apps/desktop/ui
dotnet run -c Release -r linux-x64   # 或 win-x64 / osx-arm64
```

## 播放后端探测

`MediaPlayerFactory` 按 OS 尝试：

- Linux: `libmpv.so.2`、`/usr/lib/x86_64-linux-gnu/libmpv.so.2`
- macOS: Homebrew / `/usr/local` dylib
- Windows: 可执行文件旁 `libmpv-2.dll`（可选，非硬依赖）

## 构建（box 已验证）

```sh
dotnet build -c Release -r linux-x64 --self-contained false
# → bin/Release/net10.0/linux-x64/DramaRed.UI.dll
```

## libmpv（Linux）

优先 `apt install libmpv2`。若官方镜像不可用，可改用 Debian snapshot。
box 上曾因 snapshot 504 / 依赖冲突未能装齐；UI 在探测失败时回退 `NullMediaPlayer`。

## 合规

仅学习研究、禁止商业；见根 README。
