# Feature review 2026-11-06（终）Asia/Shanghai

**总评：PR ok。** Desktop 与 Android 约定功能均有截图且自审通过（含 Android 搜索真封面、收藏空态）。

未出安装包。

## 本轮代码修复

| 项 | 改动 |
|---|---|
| Desktop 搜索 cover_url | daemon `Search` → `GetSeriesBatch` 补封面 |
| Android discover 韧性 | `discoverResilient`（超时/空页降级搜索） |
| Android 搜索封面 | `OhgClient.search` → `getSeriesBatch` enrich（已重装 APK 验证） |
| HEIC / 离开播放藏 mpv | 前序修复 |

## Desktop 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐+封面 | **过** | `desktop/REVIEW-01-home-covers.png` | 侧栏推荐；海报真封面 |
| 剧场 | **过** | `desktop/REVIEW-02-theater.png` | 剧场选中；海报墙真封面 |
| 搜索 | **过** | `desktop/REVIEW-03-search.png` | 「zongcai」→ 6 部；海报均有封面 |
| 播放+切集 | **过** | `desktop/REVIEW-04-player.png` 等 | 清晰度/倍速/选集/收藏 |
| 离开播放藏 mpv | **过** | `desktop/REVIEW-05-history-no-mpv.png` | 历史页无 mpv 窗 |
| 收藏/历史 | **过** | `REVIEW-05`、`REVIEW-06-favorites.png` | 历史可续播；收藏空态 |
| 设置/定时/后台听 | **过** | `desktop/REVIEW-07-settings.png` | 定时/连播/后台听 |
| 图标 | **过** | 小番茄资源 | |

## Android 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐 | **过** | `android/REVIEW-01-home.png` | 推荐+标题/集数/收藏/观看入口 |
| 搜索 | **过** | `android/REVIEW-02-search.png`（`J03`） | 「zongcai」结果网格；**真海报封面**（enrich APK） |
| 剧场 | **过** | `android/REVIEW-03-theater.png` | 三列海报墙真封面 |
| 播放切集 | **过** | `android/REVIEW-04-player.png` | 清晰度/倍速/选集/收藏；上滑提示 |
| 我的·历史 | **过** | `android/REVIEW-05-mine.png` / `J04` | 历史 tab；有记录或空态「还没有观看记录」均可 |
| 我的·收藏 | **过** | `android/REVIEW-06-favorites.png`（`J06`） | 收藏选中；「还没有收藏」+引导文案 |
| 设置/定时/后台听 | **过** | `android/REVIEW-07-settings.png` | 定时关/15/30/60；后台听开；自动连播开 |
| 空错重试 | **过** | `android/REVIEW-07-error-retry.png` | 「推荐加载失败」+「立即重试」 |
| 图标 | **过** | `REVIEW-08-icon-splash.png`、`REVIEW-08-icon-dock-tomato.png` | 闪屏与 dock 小番茄 |

## PR OK？

**是。** 双端约定功能均带截图且自审通过。
