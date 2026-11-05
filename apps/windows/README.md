# DramaRed Windows

Avalonia UI ↔ Go daemon ↔ libmpv。

## 进程关系

1. **drama-daemon**（Go）：封装 openhongguo `v0.2.0`，本机 HTTP JSON（默认 `127.0.0.1:17890`）。
2. **DramaRed.UI**（Avalonia）：列表/搜索；`HttpClient` 调 daemon；不直接引用 openhongguo。
3. **libmpv**：Windows 运行时由 UI 加载（本 Linux box 的 apt 源不可用且依赖链过重，**未在 box 安装 libmpv**；Windows 开发机自行放置 `libmpv-2.dll`）。

## 启动

```powershell
# 终端 1
cd apps/windows/daemon
go run ./cmd/drama-daemon

# 终端 2
cd apps/windows/ui
dotnet run
```

## 已在 box 验证

| 检查 | 结果 |
|---|---|
| `go build ./cmd/drama-daemon` | OK |
| `dotnet build -c Release`（Avalonia） | OK（0 warning） |
| curl `/health` | OK |
| curl `/api/v1/search?q=短剧` | OK（真实 SDK） |
| curl `/api/v1/discover` | OK |
| curl `/api/v1/series/{id}/episodes` | OK |
| curl `/api/v1/episodes/{id}/playback` | OK（返回 streams；DRM 时附 `contentKey`） |
| history / favorites JSON | OK |

## API

| Method | Path |
|---|---|
| GET | `/health` |
| GET | `/api/v1/search?q=` |
| GET | `/api/v1/discover` |
| GET | `/api/v1/series/{id}/episodes` |
| GET | `/api/v1/episodes/{id}/playback` |
| GET/POST/DELETE | `/api/v1/history` |
| GET/POST/DELETE | `/api/v1/favorites` |

受保护播放：响应含 `drmProtected`、`contentKey`（`sdk.ContentKey`）或 `contentKeyError`。

## 合规

仅学习研究、禁止商业；内容版权归原权利人。见根 README。
