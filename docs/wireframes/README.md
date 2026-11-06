# DramaRed 页面原型（Wireframes）

> 状态：**待确认**。先定图再改功能 UI；本目录只放原型与图标方案，**不含安装包、不含大改交互实现**。
>
> 时间：2026-11-06（Asia/Shanghai）

## 怎么读

| 类型 | 用途 | 以谁为准 |
|---|---|---|
| `*-ia.svg` | 信息架构 + 交互标注（线框） | **权威** |
| `*.jpg` | 视觉气氛参考（生成稿） | 参考；若与 IA 冲突，以 SVG / 本文为准 |
| [`icon/`](./icon/) | 应用图标主稿与导出 | 见 [`../app-icon.md`](../app-icon.md) |

已定产品约束（不可违背）：

- **Android**：顶栏「推荐」+ 搜索；底栏 首页 / 剧场 / 我的；首页竖滑换剧 → 点进播放再切集；播放竖滑切集 + 预加载；剧场瀑布流；我的 = 历史 + 收藏 + 设置；设置含定时停；后台可听；**不做下载**。
- **Desktop**：左侧导航 + 海报网格；播放 = 9:16 预览 + 旁侧选集/控件；不照搬手机底栏。

---

## Android

| 页面 | IA 线框 | 视觉参考 | 信息架构 / 交互 |
|---|---|---|---|
| 首页推荐 | [android/home-ia.svg](./android/home-ia.svg) | [android/home.jpg](./android/home.jpg) | 竖滑换剧；点封面进播放；顶栏搜索 |
| 剧场 | [android/theater-ia.svg](./android/theater-ia.svg) | [android/theater.jpg](./android/theater.jpg) | 三列瀑布流封面；点进播放 |
| 我的 | [android/mine-ia.svg](./android/mine-ia.svg) | [android/mine.jpg](./android/mine.jpg) | 历史续播 + 收藏 + 设置入口；**仅三键底栏**（生成图若出现「发现/缓存」等 Tab，忽略） |
| 搜索 | [android/search-ia.svg](./android/search-ia.svg) | [android/search.jpg](./android/search.jpg) | 首页顶栏旁进入；结果点进播放 |
| 播放 | [android/player-ia.svg](./android/player-ia.svg) | [android/player.jpg](./android/player.jpg) | 竖屏沉浸；上滑下一集 / 下滑上一集；预加载；清晰度·倍速·选集·收藏；定时停在设置 |
| 设置 | [android/settings-ia.svg](./android/settings-ia.svg) | [android/settings.jpg](./android/settings.jpg) | 从「我的」进入；定时停 / 后台听 / 自动连播 |

浏览页：[index.html](./index.html)

---

## Windows / Desktop

| 页面 | IA 线框 | 视觉参考 | 信息架构 / 交互 |
|---|---|---|---|
| 侧栏壳（推荐网格） | [desktop/shell-ia.svg](./desktop/shell-ia.svg) | [desktop/shell.jpg](./desktop/shell.jpg) | 侧栏：推荐 / 剧场 / 搜索 / 播放 / 历史 / 收藏 / 设置；海报网格找剧 |
| 播放双栏 | [desktop/player-ia.svg](./desktop/player-ia.svg) | [desktop/player.jpg](./desktop/player.jpg) | 左 9:16 预览 + 右选集/清晰度/倍速/连播/收藏；键盘空格·↑↓·←→；定时停在设置（生成图侧栏若混入「下载」等，忽略） |

---

## 确认清单（请你勾）

- [ ] Android 六页 IA 是否 OK
- [ ] Desktop 侧栏项与播放双栏是否 OK
- [ ] 图标主稿（红 play + 竖屏框）是否采用
- [ ] 确认后再动功能 UI / 出包

## 生成图已知偏差（勿当需求）

1. `mine.jpg` 底栏多画了「发现 / 缓存」→ **实际只有 首页 / 剧场 / 我的**。
2. `desktop/player.jpg` 侧栏混入下载等 → **实际侧栏七项见 shell-ia.svg**；预览应为 **9:16**，非 16:9 铺满。
3. 部分视觉稿偏高保真插画 → 实现仍按深色沉浸 + 橙红强调（见 `docs/ux-research.md`）。
