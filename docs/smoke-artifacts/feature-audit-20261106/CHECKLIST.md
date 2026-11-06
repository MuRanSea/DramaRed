# Feature checklist — DramaRed audit 2026-11-06 (Asia/Shanghai)

Capture dir: `docs/smoke-artifacts/feature-audit-20261106/{desktop,android}/`
Prior review: `docs/smoke-artifacts/feature-review-20261106/` (many static shots; behavioral gaps below).

**prior_gap=yes** = old REVIEW had no honest before/after / action evidence (or only a static control presence shot).

Pass criteria always include: Chinese copy only (no English timeout stack); density/chrome vs mature apps in `MATURE-COMPARE.md`.

| id | platform | what to capture | pass criteria vs mature | prior_gap |
|---|---|---|---|---|
| D-CHROME-01 | Desktop | Cold window: top chrome + OS title | Top bar = search + 隐藏继续听/刷新/设置 only; **no** stacked tomato/「DramaRed 桌面端」 in-app chrome; OS title may be `DramaRed` | yes (old shots still showed in-app 「DramaRed 桌面端」 branding) |
| D-HOME-01 | Desktop | 推荐页海报墙真封面 | 侧栏「推荐」选中；网格有封面+标题；密度接近 Spotify/同类 PC 海报墙 | no (REVIEW-01-home-covers) |
| D-HOME-02 | Desktop | 推荐空态/错误 + 立即重试 | 标题说明原因 + 单一主按钮；无 `HttpRequestException`/`502` 原文 | partial (08-home-error-retry 有；超时中文未证) |
| D-HOME-03 | Desktop | 推荐超时中文（0.3.2+） | 人为慢/断网后文案含「超时/请重试/搜索」等中文；**禁止** `HttpClient.Timeout` / `90 seconds` / `A task was canceled` | **yes** |
| D-THEATER-01 | Desktop | 剧场海报墙 | 侧栏剧场选中；真封面网格 | no (REVIEW-02) |
| D-THEATER-02 | Desktop | 剧场空/错 | 同 HomeEmpty 原则 | yes |
| D-SEARCH-01 | Desktop | 顶栏搜索结果（如 zongcai） | 结果网格真封面；侧栏可切到搜索页 | no (REVIEW-03*) |
| D-SEARCH-02 | Desktop | 搜索无结果空态 | 明确「无结果」+ 可改词；非空白死黑 | **yes** (仅 Hint 文字，无卡片；旧审未专拍) |
| D-SEARCH-03 | Desktop | 搜索失败中文 | FriendlyError；无英文堆栈 | **yes** |
| D-PLAYER-01 | Desktop | 播放页布局 9:16 + 旁侧选集 | 左预览 9:16；右清晰度/倍速/连播/收藏/集芯片；mpv 独立窗可选入镜 | no (REVIEW-04) |
| D-PLAYER-02 | Desktop | 切集（下一集/芯片） | 当前集高亮变化；状态栏/PlayerStatus 更新 | partial (REVIEW-04-player-next 有切集，弱) |
| D-PLAYER-03 | Desktop | **清晰度切换动作** | 改 ComboBox 前后各一张；状态反映新清晰度（或「切换中」） | **yes** |
| D-PLAYER-04 | Desktop | **倍速切换动作** | 1.0→1.5/2.0 前后对比；PlayerStatus/后端反映 | **yes** |
| D-PLAYER-05 | Desktop | **自动连播触发** | 一集结束后自动进下一集的状态文案「自动连播：…」 | **yes** |
| D-PLAYER-06 | Desktop | **预加载证据** | 状态栏出现「已预加载下一集 …」 | partial (REVIEW-04 文案曾出现；需本轮复现) |
| D-PLAYER-07 | Desktop | 播放页空态 | 「尚未选择剧集」+「去推荐选剧」 | **yes** |
| D-HIST-01 | Desktop | 历史列表有记录 | 封面+看到第几集+时间 | partial (REVIEW-05 文件很小，疑空/弱) |
| D-HIST-02 | Desktop | **历史续播点击** | 点一项进入播放且进度/集数对得上 | **yes** |
| D-HIST-03 | Desktop | 历史空态卡片 | 「还没有观看记录」+ 去首页 | partial |
| D-HIST-04 | Desktop | 离开播放后 mpv 隐藏 | 在历史/其他页时无残留播放窗 | no (REVIEW-05-history-no-mpv) |
| D-FAV-01 | Desktop | 收藏有内容网格 | 从播放页点收藏后收藏页出现海报 | **yes** (旧 REVIEW-06 仅空) |
| D-FAV-02 | Desktop | 收藏空态 | 应有与 History 同级的空态卡片+主操作；**代码现状仅 Hint「还没有收藏」** → 记 UX bug | **yes** |
| D-SET-01 | Desktop | 设置页播放偏好 | 定时关/15/30/60；自动连播；后台听说明 | no (REVIEW-07) |
| D-SET-02 | Desktop | **定时倒计时进行中** | 设 15 分后播放页 TimerHint 出现 `定时停止倒计时 MM:SS` | **yes** |
| D-SET-03 | Desktop | 定时触发暂停 | `定时停止已触发` | **yes** |
| D-BG-01 | Desktop | **隐藏继续听** | 点按钮或 Ctrl+H 后主窗隐藏；音频仍播；再唤回 | **yes** |
| D-BG-02 | Desktop | 藏窗期间切侧栏意图 | 唤回后仍在播/历史可续 | **yes** |
| D-KEY-01 | Desktop | 快捷键实操 | 空格暂停、↓下一集、←→ 快进、M 静音、Ctrl+F 聚焦搜索、Esc 离播放页 — 至少 3 个有状态反馈图 | **yes** |
| D-ICON-01 | Desktop | 窗口/任务栏图标 | 小番茄资源一致、无破图 | partial |
| A-CHROME-01 | Android | 顶栏仅推荐+搜索 | 无多余标题堆叠；底栏 首页/剧场/我的 | partial |
| A-HOME-01 | Android | 首页推荐单卡 | 标题/集数/收藏/观看入口 | no (REVIEW-01) |
| A-HOME-02 | Android | **竖滑换剧序列** | ≥2 帧不同剧（上滑前后） | **yes** |
| A-HOME-03 | Android | 推荐失败+立即重试 | StatusPane 中文 | no (REVIEW-07-error-retry) |
| A-SEARCH-01 | Android | 搜索结果真封面 | 网格 enrich 封面 | no (REVIEW-02/J03) |
| A-SEARCH-02 | Android | 搜索空/错 | 友好空态 | **yes** |
| A-THEATER-01 | Android | 三列剧场墙 | 真封面瀑布 | no (REVIEW-03) |
| A-PLAYER-01 | Android | 播放页控件露出 | 清晰度/倍速/选集/收藏；上滑提示 | weak (REVIEW-04 仅 70KB，疑黑屏/未真正播) |
| A-PLAYER-02 | Android | **清晰度切换动作** | 前后状态 | **yes** |
| A-PLAYER-03 | Android | **倍速切换动作** | 前后状态 | **yes** |
| A-PLAYER-04 | Android | 上下滑切集 | EpisodeSwipe / PageView 换集 | **yes** |
| A-PLAYER-05 | Android | 自动连播 | 终集后进下一集文案 | **yes** |
| A-PLAYER-06 | Android | 预加载 | 日志或无卡顿切集旁证 | **yes** |
| A-MINE-01 | Android | 我的·历史 | 有记录或空态 | no (REVIEW-05) |
| A-MINE-02 | Android | 历史续播 | 点进后集数/进度 | **yes** |
| A-FAV-01 | Android | 收藏空态 | 「还没有收藏」+引导 | no (REVIEW-06) |
| A-FAV-02 | Android | 收藏有内容 | 追剧后网格 | **yes** |
| A-SET-01 | Android | 设置定时/后台听/连播 | 芯片 关/15/30/60；开关 | no (REVIEW-07-settings) |
| A-SET-02 | Android | **定时倒计时/触发** | 播放中可见倒计时或触发文案 | **yes** |
| A-BG-01 | Android | **后台听** | 开后台听 → Home/多任务后再回，音频策略符合设置 | **yes** |
| A-ICON-01 | Android | 闪屏/launcher 小番茄 | dock+splash | no (REVIEW-08*) |

## Code/static UX bugs found before new screenshots

1. **Desktop 收藏无空态卡片**：`PageFavorites` 只有 Hint 改文案，缺少 `HistoryEmpty` 同级 Border+主按钮（对照成熟 empty 模式与本 App 历史页）。
2. **Desktop 搜索无结果无卡片**：仅 `SearchHint="无结果"`，主区可一片空。
3. **旧 Desktop 截图顶栏仍见「DramaRed 桌面端」**：当前 `MainWindow.axaml` 顶栏已无该文案（仅 OS `Title=DramaRed`）；本轮必须用 D-CHROME-01 核实是否还有残留资源/自定义 chrome。
4. **Android REVIEW-04-player.png 过轻（~70KB）**：不能当作「在线播放合格」证据；需重拍真正出画/控件层。
5. **行为功能普遍缺 before/after**：清晰度、倍速、定时倒计时、自动连播、后台听、快捷键 — 旧 REVIEW 把「控件在页面上」当成「功能测过」。

## Out of scope (product)

- 下载 / 打包 Windows zip / GitHub Release / 让用户装包
