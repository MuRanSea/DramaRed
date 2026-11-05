# DramaRed Windows

Avalonia UI ↔ Go daemon ↔ libmpv。

## 进程关系

1. **drama-daemon**（Go）：封装 openhongguo `v0.2.0`，提供本机 HTTP JSON API（默认 `127.0.0.1:17890`）。
2. **DramaRed.UI**（Avalonia）：列表/搜索/收藏/历史；通过 `HttpClient` 调 daemon；**不**直接引用 openhongguo。
3. **libmpv**：由 UI 加载，负责解码渲染；播放 URL / 内容密钥来自 daemon 的 `/playback` 接口。

选用 HTTP 而非 stdio JSON-RPC 的理由见 [`docs/architecture.md`](../../docs/architecture.md)。

## 启动顺序

```powershell
# 终端 1 — daemon
cd apps/windows/daemon
go run ./cmd/drama-daemon

# 终端 2 — UI（需 .NET 8 SDK + Avalonia 工作负载/还原）
cd apps/windows/ui
dotnet restore
dotnet run
```

健康检查：

```powershell
curl http://127.0.0.1:17890/health
```

## libmpv

- 开发机需提供可用的 `libmpv-2.dll`（或通过 MPV NuGet / 自行分发）。
- 本骨架 UI 仅留 `MpvPlayerHost` 占位控件，未链真实 mpv。
- 后台继续听、定时停止在 UI ViewModel 层预留属性，待播放器接入后实现。

## API 一览

| 方法 | 路径 |
|---|---|
| GET | `/health` |
| GET | `/api/v1/search?q=` |
| GET | `/api/v1/discover` |
| GET | `/api/v1/series/{id}/episodes` |
| GET | `/api/v1/episodes/{id}/playback` |
| GET/POST/DELETE | `/api/v1/history` |
| GET/POST/DELETE | `/api/v1/favorites` |

## 工具缺口

若本机缺少：

| 工具 | 影响 |
|---|---|
| Go ≥ 1.22 | 无法编译/运行 daemon |
| .NET 8 SDK | 无法编译 Avalonia UI |
| libmpv | 无法真实播放（骨架可先跑通 API） |

## 合规

仅学习研究、禁止商业；内容版权归原权利人。详见仓库根 README 免责声明。
