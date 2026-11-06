# Mature product comparison — DramaRed feature audit (2026-11-06 Asia/Shanghai)

Sources (fetched/searched this turn):
- 红果短剧 App Store / 官网 hongguoshort.com.cn（单列推荐、剧场九宫格、倍速/选集/小窗、一键追剧）
- 抖音电脑版评测与官方下载页（左侧导航 + 顶栏搜索 + 键鼠快捷键；倍速 0.75–2.0；连播）
- 仓库既有 `docs/ux-research.md` / `docs/desktop-ui.md`（hongguo-open-player、开心果、Spotify/Netflix 桌面密度）

DramaRed **不做下载**（产品约束）；成熟 App 的离线下载/金币/评论不作为必须对齐项，只作对照说明。

## Pattern table

| 模式 | 成熟参考 | DramaRed 期望 | 审计关注 |
|---|---|---|---|
| 手机首页 | 红果：单列竖滑沉浸找剧；顶栏瘦（推荐+搜索） | Android：`PageView` 竖滑 → 点进播放再切集；顶栏推荐+搜索 | 必须有**竖滑过程**截图，不是单帧海报 |
| 手机剧场 | 红果：九宫格/三列找剧 | Android：三列 `GridView` 瀑布墙 | 真封面 + 滚动密度 |
| 手机播控 | 任意选集、倍速、小窗；信息压画面底 | 清晰度/倍速/选集/收藏/上下滑切集/预加载/定时/后台听 | **动作后**状态变化图，不是控件摆在那 |
| 手机我的 | 追剧/历史入口清楚；空态可跳转 | 历史+收藏+设置；空态 StatusPane | 空态 vs 有内容各一张 |
| 桌面导航 | 抖音 PC：左侧栏 + 顶搜索；**不**搬手机底栏 | 侧栏 推荐/剧场/搜索/播放/历史/收藏/设置；顶栏仅搜索+动作 | 顶栏**禁止**叠番茄/DramaRed 文案标题 |
| 桌面播放 | 同类 PC：9:16 预览 + 旁侧选集/倍速/连播 | 左 9:16 + 右芯片；独立 mpv 窗 | 切清晰度/倍速/连播/定时倒计时要有前后对比 |
| 桌面密度 | Spotify：侧栏找内容；卡片圆角轻分隔 | 海报墙 WrapPanel；圆角 ~12 | 死黑大空、英文堆栈 = 不合格 |
| 空/错 | Netflix/Primer：说明为什么空 + **一个**主操作；错误≠空 | Desktop HomeEmpty/TheaterEmpty/HistoryEmpty；Android StatusPane | 搜索无结果、收藏空、超时中文（禁止 `HttpClient.Timeout` / `90 seconds`） |
| 键鼠 | 抖音 PC：空格/↑↓/←→；提示可发现 | 空格/↑↓/Page/←→/M/Ctrl+F/Ctrl+H/Esc | 快捷键**实操**截图或状态栏反馈 |
| 后台听 | 红果小窗；PC 隐藏续播 | 「隐藏继续听」/Ctrl+H；音频继续 | 藏窗后侧栏切页 + 音频仍在播的证据 |

## What DramaRed should NOT copy

- 红果下载 / 金币 / 社区评论（产品明确不做下载；其余非首版范围）
- 手机底栏搬到 Desktop
- 把竖滑全屏当 Desktop 唯一播放形态

## Honest bar for this audit

Prior `feature-review-20261106/REVIEW.md` marked **PR ok** with mostly **static** page shots. User complaint stands: several **behavioral** features had no before/after evidence. This audit’s CHECKLIST marks those as `prior_gap=yes` and requires new captures under `desktop/` / `android/`.
