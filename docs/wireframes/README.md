# DramaRed 页面原型（详细线框）

> 状态：**待确认**。先定图再改功能 UI；**不含安装包、不含大改交互实现**。  
> 时间：2026-11-06（Asia/Shanghai）  
> 图标：小番茄 → 见 [`../app-icon.md`](../app-icon.md)

## 怎么读

| 类型 | 用途 | 以谁为准 |
|---|---|---|
| `*-0N-*.svg` | **多状态详细线框**（控件尺寸 + 交互标注） | **权威** |
| `*-ia.svg` | 单页 IA 总览 | 补充 |
| `*.jpg` | 气氛参考 | 冲突时忽略 JPG |
| [`index.html`](./index.html) | 本地一页览全部详细图 | |

已定约束：Android 顶栏推荐+搜索、底栏三键、首页竖滑点进播放、播放竖滑+预加载、剧场瀑布流、我的=历史+收藏+设置、定时停在设置、后台听、不做下载；Desktop 侧栏+网格、播放 9:16+旁侧控件。

---

## Android 详细线框（每页多状态）

### 首页推荐
| 状态 | 文件 |
|---|---|
| 有内容 | [android/home-01-content.svg](./android/home-01-content.svg) |
| 加载 | [android/home-02-loading.svg](./android/home-02-loading.svg) |
| 空 | [android/home-03-empty.svg](./android/home-03-empty.svg) |
| 错误 | [android/home-04-error.svg](./android/home-04-error.svg) |
| IA 总览 | [android/home-ia.svg](./android/home-ia.svg) |

规格摘要：顶栏 56 · 搜索热区 ≥44² · 主卡圆角 14 · 底栏 60 · 竖滑换剧、点封面进播放。

### 剧场
| 状态 | 文件 |
|---|---|
| 有内容 | [android/theater-01-content.svg](./android/theater-01-content.svg) |
| 加载（骨架） | [android/theater-02-loading.svg](./android/theater-02-loading.svg) |
| 空 | [android/theater-03-empty.svg](./android/theater-03-empty.svg) |
| 错误 | [android/theater-04-error.svg](./android/theater-04-error.svg) |

规格：三列 · 封面约 104×150 · 间距 8 · 点封面进播放。

### 我的
| 状态 | 文件 |
|---|---|
| 有内容 | [android/mine-01-content.svg](./android/mine-01-content.svg) |
| 历史空 | [android/mine-02-empty-history.svg](./android/mine-02-empty-history.svg) |
| IA 总览 | [android/mine-ia.svg](./android/mine-ia.svg) |

规格：历史行 ≈55 / 缩略 48 · 入口行 56 · 点进续播 · 设置入口。

### 搜索
| 状态 | 文件 |
|---|---|
| 默认 | [android/search-01-default.svg](./android/search-01-default.svg) |
| 加载 | [android/search-02-loading.svg](./android/search-02-loading.svg) |
| 有结果 | [android/search-03-results.svg](./android/search-03-results.svg) |
| 空 | [android/search-04-empty.svg](./android/search-04-empty.svg) |
| 错误 | [android/search-05-error.svg](./android/search-05-error.svg) |

规格：搜索框高 44 · 结果行 ≈90 · 点进播放。

### 播放
| 状态 | 文件 |
|---|---|
| 播放中 | [android/player-01-playing.svg](./android/player-01-playing.svg) |
| 拉流加载 | [android/player-02-loading.svg](./android/player-02-loading.svg) |
| 选集 sheet | [android/player-03-episode-sheet.svg](./android/player-03-episode-sheet.svg) |
| 错误 | [android/player-04-error.svg](./android/player-04-error.svg) |
| 控件明细 | [android/player-05-controls-detail.svg](./android/player-05-controls-detail.svg) |

规格：无底栏 · 控件行高 36 · 进度热区 ≥24 · 上滑下一集/下滑上一集 · 预加载 · 清晰度/倍速/选集/收藏 · 定时停在设置。

### 设置
| 状态 | 文件 |
|---|---|
| 默认 | [android/settings-01-default.svg](./android/settings-01-default.svg) |
| 定时已选 | [android/settings-02-timer-active.svg](./android/settings-02-timer-active.svg) |

规格：芯片高 36 · 开关 44×26 · 定时停/后台听/自动连播 · 无下载。

---

## Desktop 详细线框

### 侧栏壳
| 状态 | 文件 |
|---|---|
| 推荐网格 | [desktop/shell-01-home-grid.svg](./desktop/shell-01-home-grid.svg) |
| 加载 | [desktop/shell-02-loading.svg](./desktop/shell-02-loading.svg) |
| 空 | [desktop/shell-03-empty.svg](./desktop/shell-03-empty.svg) |
| 错误 | [desktop/shell-04-error.svg](./desktop/shell-04-error.svg) |
| 剧场/搜索说明 | [desktop/shell-05-theater-search.svg](./desktop/shell-05-theater-search.svg) |

规格：侧栏 180 · 搜索高 36 · 海报约 124×168 · 七项导航。

### 播放双栏
| 状态 | 文件 |
|---|---|
| 双栏播放 | [desktop/player-01-dual.svg](./desktop/player-01-dual.svg) |
| 拉流加载 | [desktop/player-02-loading.svg](./desktop/player-02-loading.svg) |
| 错误 | [desktop/player-03-error.svg](./desktop/player-03-error.svg) |
| 未选剧 idle | [desktop/player-04-empty-idle.svg](./desktop/player-04-empty-idle.svg) |

规格：左 9:16（例 270×480）· 右栏 ≥360 · 集芯片 48×36 · 键盘 Space/↑↓/←→/M/Esc。

---

## 确认清单

- [ ] Android 各页多状态是否够细
- [ ] Desktop 壳 + 播放多状态是否 OK
- [ ] 小番茄图标是否采用
- [ ] 确认后再动功能 UI / 出包

## 旧 JPG 偏差（仍忽略）

`mine.jpg` 多余 Tab、`desktop/player.jpg` 下载项与非 9:16 → 以本 README 链接的 SVG 为准。
