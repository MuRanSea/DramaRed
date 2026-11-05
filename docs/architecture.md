# DramaRed 架构

## 目标边界

| 做 | 不做 |
|---|---|
| 搜索、推荐/书城、分集、在线播放 | 下载 / 离线缓存打包 |
| 清晰度、倍速、自动连播 | 账号体系 / 社交 |
| 历史续播、收藏、定时停止 | 商业分发 |
| 后台/隐藏继续听（预留） | 绕过版权或 DRM 破解（仅使用 SDK 提供的播放信息） |

两端均锁定 **openhongguo v0.2.0**。

## Android（Flutter）

```
┌─────────────────────────────────────────┐
│  UI: Home / Search / Player / Fav / Hist │
├─────────────────────────────────────────┤
│  services/  (Client 封装、本地历史/收藏)   │
├─────────────────────────────────────────┤
│  openhongguo 0.2.0  (gomobile 原生库)     │
│  media_kit          (播放；ClearKey 预留) │
└─────────────────────────────────────────┘
```

- **业务**：直接调用 `OpenhongguoClient`（discover / search / listEpisodes / resolvePlayback）。
- **播放**：`media_kit` + `media_kit_video`；ClearKey / 后台音频会话仅在依赖与注释中预留，本骨架不实现。
- **本地状态**：历史 / 收藏先用简单本地持久化占位（SharedPreferences / 文件），后续可换 isar/hive。

模块建议：

| 路径 | 职责 |
|---|---|
| `lib/pages/*` | 页面占位 |
| `lib/services/ohg_client.dart` | openhongguo 封装 |
| `lib/services/history_store.dart` | 播放历史 / 续播进度 |
| `lib/services/favorites_store.dart` | 收藏 |
| `lib/services/player_controller.dart` | media_kit 控制（占位） |

## Windows（Avalonia + Go + libmpv）

```
┌──────────────────┐  HTTP JSON   ┌──────────────────────────┐
│  Avalonia UI     │ ◄──────────► │  Go daemon (drama-daemon) │
│  - 列表/搜索/收藏 │  127.0.0.1   │  openhongguo/sdk v0.2.0  │
│  - 历史/设置     │  :17890      │  + 本地 history/favorites │
│  - 嵌入播放区    │              └──────────────────────────┘
│        │         │
│        ▼         │
│  libmpv (本地)   │  播放 URL / 密钥由 daemon 的 playback 接口返回
└──────────────────┘
```

### 为何选 HTTP 而非 JSON-RPC over stdio

首版选用 **本机 HTTP JSON API**（默认 `http://127.0.0.1:17890`）：

- Avalonia 用 `HttpClient` 即可，调试可用 curl / 浏览器。
- 进程崩溃可独立重启 daemon，无需重绑 stdin/stdout。
- 后续若需加固，可再加 named pipe / 鉴权 token；stdio JSON-RPC 可作为备选，但本仓库文档与占位代码统一为 HTTP。

### 接口占位（daemon）

| Method | Path | 说明 |
|---|---|---|
| GET | `/health` | 存活 |
| GET | `/api/v1/search?q=` | 搜索 |
| GET | `/api/v1/discover` | 推荐/书城 |
| GET | `/api/v1/series/{id}/episodes` | 分集 |
| GET | `/api/v1/episodes/{id}/playback` | 播放信息（清晰度流） |
| GET/POST/DELETE | `/api/v1/history` | 播放历史 / 续播 |
| GET/POST/DELETE | `/api/v1/favorites` | 收藏 |

实现状态：路由与 DTO 已就位；ohg 调用处标 `TODO`，本地 store 为内存/JSON 文件占位。

### 模块边界

| 组件 | 负责 | 不负责 |
|---|---|---|
| Avalonia UI | 交互、libmpv 渲染与控制（倍速/连播/定时停） | 直接引用 openhongguo |
| Go daemon | 封装 SDK、历史/收藏持久化、播放元数据 | 视频解码 / 窗口 |
| libmpv | 解码与渲染、后台音频能力预留 | 业务 API |

## 数据流（播放一集）

1. UI 搜索 → daemon `/search` → openhongguo `Search`
2. UI 选剧 → `/series/{id}/episodes` → `ListEpisodes`
3. UI 选集约 → `/episodes/{id}/playback` → `ResolvePlayback`
4. UI 把返回的 stream URL（及必要时的内容密钥）交给播放器（Android: media_kit；Windows: libmpv）
5. 进度写入 history；收藏走 favorites

## 安全与合规提示

- 仅绑定 localhost；不要把 daemon 暴露到公网。
- 遵守 openhongguo 免责声明：学习研究、禁止商业、内容版权归原权利人。
- 不做下载、不做批量爬取。


## 播放密钥（受保护流）

- Flutter：`resolvePlayback` 返回 `PlaybackResult.contentKey`（SDK 已推导）。
- Windows daemon：`/api/v1/episodes/{id}/playback` 在 `ErrDRMProtected` 时附加 `contentKey`（`sdk.ContentKey`）。
- 播放器侧：media_kit / libmpv 目前以 `demuxer-lavf-o=decryption_key=<hex>` 作 best-effort；完整 CENC ClearKey 仍可能需后续平台适配。
