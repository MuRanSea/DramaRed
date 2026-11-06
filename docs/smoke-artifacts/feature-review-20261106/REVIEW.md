# Feature review 2026-11-06（Asia/Shanghai）

**总评：PR 不算 OK。** Desktop 关键路径（HEIC 封面、播放、离开播放藏 mpv、设置）已自审通过；Android 本轮模拟器大量 ANR/卡闪屏，多数功能截图无效，不能算过。

未出安装包。

## 本轮代码修复

| 项 | 改动 |
|---|---|
| HEIC 封面 | `CoverLoader` 下载后若 HEIC/解码失败，走 `ffmpeg` 转 PNG |
| 离开播放页 mpv 遮挡 | `ShowPage` 调 `SetVideoWindowVisible`；离开时 `vid=no` + 移到屏外 + `force-window=no` |
| 其它 | Android `debugShowCheckedModeBanner: false`；`DRAMARED_AUTO_SEARCH` 便于抓搜索图 |

## Desktop 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐+封面 | **过** | `desktop/REVIEW-01-home-covers.png` | 侧栏推荐选中；海报网格真封面（非「封面」占位） |
| 剧场 | **过** | `desktop/REVIEW-02-theater.png` | 剧场选中；宽屏海报墙真封面 |
| 搜索 | **部分过** | `desktop/REVIEW-03-search.png` | 顶栏「总裁」、结果「搜索到 6 部」标题在；**封面空**——daemon `/api/v1/search` 条目无 `cover_url`（非 CoverLoader 问题） |
| 播放+切集 | **过** | `desktop/REVIEW-04-player.png`、`REVIEW-04-player-next.png` | 播放页封面/清晰度/倍速/选集/收藏；mpv 独立窗在壳右侧 `360x640+1400+40` 不盖住壳；选集高亮与预加载文案可见 |
| 离开播放藏 mpv | **过** | `desktop/REVIEW-05-history-no-mpv.png` | 历史页选中、列表有封面；`xwininfo` 无 mpv 窗（对比播放时存在） |
| 收藏/历史 | **过** | `REVIEW-05-…`、`REVIEW-06-favorites.png` | 历史 1 条可续播；收藏空态「还没有收藏」 |
| 设置/定时/后台听 | **过** | `desktop/REVIEW-07-settings.png` | 定时停播、自动连播、隐藏继续听说明、libmpv 就绪 |
| 图标 | **过** | `icon/dramared-icon-tomato.png` 等 | 小番茄资源在仓库与包内 |

补充原始抓图：`desktop/T*`、`U*`、`X03-*`、`R*`（同目录）。

## Android 自审

| 功能 | 结论 | 证据图 | 审图说明 |
|---|---|---|---|
| 首页推荐 | **不过** | `android/REVIEW-01-home-earlier.png`、`D-home-*` | 早先有推荐卡但中心无画面；本轮多为加载失败/ANR |
| 搜索 | **不过** | `android/D02-search.png` | ANR「DramaRed isn't responding」 |
| 剧场 | **不过** | `android/D03-theater.png` | 仍停在推荐+ANR，未真正进剧场 |
| 播放切集 | **不过** | （无有效图） | 模拟器未进播放页 |
| 收藏/历史 | **不过** | `android/D05-mine.png` | ANR |
| 设置/定时/后台听 | **不过** | `android/D06-settings-attempt.png` | 只抓到闪屏 |
| 空错重试 | **过（壳）** | `android/REVIEW-07-error-retry.png` | 「推荐加载失败」+「立即重试」空错态符合细稿 |
| 图标 | **过** | `android/REVIEW-08-icon-splash.png`、`REVIEW-08-icon-asset.png` | 闪屏小番茄；资源文件在 |

`A*`/`B*` 大量为桌面/ANR，**不作过关证据**。

## 明确不过 / 待修

1. **Android 模拟器稳定性**：TCG 模拟器上首帧慢、推荐易失败、交互易 ANR——需真机或加速环境补全功能截图后再认 OK。  
2. **Search API 无 cover_url**：桌面搜索结果海报空，应在 daemon/openhongguo 映射补封面字段。  
3. **个别首页封面偶发占位**（如 `V01` 首张）：ffmpeg 并发/超时，可再加队列或重试。

## PR OK？

**否。** Desktop 关键修复+截图可合入作进度；按用户标准「每个功能带截图且自审过才算 PR ok」，Android 未过 → **整 PR 不算 ok**。
