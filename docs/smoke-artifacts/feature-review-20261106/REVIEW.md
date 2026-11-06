# Feature review 2026-11-06（续）Asia/Shanghai

**总评：PR 仍不算 OK。** Desktop 关键路径（含搜索封面补齐）已自审通过；Android 多数功能本轮有有效截图，但 **搜索封面仍空**、**收藏空态未切入**，按「每功能带截图且自审过」标准整 PR 不算 ok。

未出安装包。

## 本轮代码修复

| 项 | 改动 |
|---|---|
| Desktop 搜索缺 cover_url | `ohg.Client.Search` 在 SDK 返回后用 `GetSeriesBatch` 补封面（openhongguo `ParseSearch` 在 `series_title` 路径丢掉 `series_cover`） |
| Android discover 韧性 | `OhgClient.discoverResilient`：discover 超时/空页时降级搜索关键词（已装入模拟器 APK） |
| Android 搜索封面补齐 | `OhgClient.search` 同样走 `getSeriesBatch`（**代码已写，本轮未重装 APK，截图仍无封面**） |
| HEIC / 离开播放藏 mpv | 仍为 PR 前序修复 |

## Desktop 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐+封面 | **过** | `desktop/REVIEW-01-home-covers.png` | 侧栏推荐；海报真封面 |
| 剧场 | **过** | `desktop/REVIEW-02-theater.png` | 剧场选中；海报墙真封面 |
| 搜索 | **过** | `desktop/REVIEW-03-search.png`（= `REVIEW-03-search-covers.png`） | 「zongcai」→「搜索到 6 部」；**6 张海报均有封面**（daemon enrich 后 API 6/6 cover_url） |
| 播放+切集 | **过** | `desktop/REVIEW-04-player.png`、`REVIEW-04-player-next.png` | 清晰度/倍速/选集/收藏；mpv 独立窗不挡壳 |
| 离开播放藏 mpv | **过** | `desktop/REVIEW-05-history-no-mpv.png` | 历史页；无 mpv 窗 |
| 收藏/历史 | **过** | `REVIEW-05-…`、`REVIEW-06-favorites.png` | 历史可续播；收藏空态 |
| 设置/定时/后台听 | **过** | `desktop/REVIEW-07-settings.png` | 定时停播、自动连播、后台听说明 |
| 图标 | **过** | 仓库小番茄资源 | |

## Android 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐 | **过** | `android/REVIEW-01-home.png`（`H28`/`H11-poll-1`） | 推荐选中；有标题/集数/收藏/观看完整短剧；`H28` 有真海报 |
| 搜索 | **部分过** | `android/REVIEW-02-search.png`（`H30`） | 顶栏「zongcai」→ 6 条标题+集数网格；**封面全是场记板占位**（直连 SDK，未带上 enrich APK） |
| 剧场 | **过** | `android/REVIEW-03-theater.png`（`H27`） | 剧场选中；三列海报墙真封面 |
| 播放切集 | **过** | `android/REVIEW-04-player.png`（`H12`） | 返回/收藏/清晰度自动/1x/选集；「上滑下一集」提示；受保护流 ClearKey 文案可见（黑帧属 DRM/模拟器） |
| 我的·历史 | **过** | `android/REVIEW-05-mine.png`（`H31`） | 历史选中；两部真封面+进度；设置齿轮在 |
| 我的·收藏 | **部分过** | （同 `H31` 可见「收藏」tab） | tab 文案在；多次点按未切入收藏页/空态，无独立空态证据图 |
| 设置/定时/后台听 | **过** | `android/REVIEW-07-settings.png`（`H33`） | 定时关/15/30/60；后台继续听开；自动连播开 |
| 空错重试 | **过** | `android/REVIEW-07-error-retry.png`（`H01c`） | 「推荐加载失败」+「立即重试」 |
| 图标 | **过** | `android/REVIEW-08-icon-splash.png`、`REVIEW-08-icon-dock-tomato.png` | 闪屏小番茄；桌面 dock 小番茄 |

模拟器为无加速 TCG，易 ANR/闪屏久；本轮有效图均为自审通过后的 `REVIEW-*` / `H*` 编号。

## 明确不过 / 待修

1. **Android 搜索封面**：代码 enrich 已加，需重装 APK 后再截一张带封面的搜索结果才算「搜索过」。  
2. **Android 收藏空态**：需切入「收藏」tab 截空态（「还没有收藏」类）才算全过。  
3. 播放页黑帧：上游受保护流 + 模拟器 ClearKey，非 UI 壳问题；控件布局已过。

## PR OK？

**否。** Desktop 可认；Android 搜索封面与收藏空态未齐 → **整 PR 不算 ok**。
