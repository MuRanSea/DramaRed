# Desktop feature audit 2026-11-06 — REVIEW（终评）Asia/Shanghai

对照：红果（竖滑/剧场/倍速选集）、抖音 PC（侧栏+顶搜索）、空错「原因+主操作」。

**未发 GitHub Release / 未出 zip。** 代码在 [PR #29](https://github.com/MuRanSea/DramaRed/pull/29)（`fix/desktop-feature-audit-bugs-20261106`）。

证据：`desktop/A01`–`A20`（修前）、`desktop/F01`–`F09`（修后关键帧）。WIP 原文见 `REVIEW-desktop-wip.md`。

---

## 总评（终）

| 阶段 | 结论 |
|---|---|
| 修前（A 组） | **不通过 PR ok** — 清晰度英文炸、定时停卡死、空态弱、双设置、收藏无封面 |
| 修后 F01–F09 | 上述 CRITICAL/HIGH **已过截图验证** |
| 残差（F 后 computerUse） | 进收藏/历史后侧栏导航偶发卡在「历史」— **已在同 PR 分支再修**（见 FIXES §9） |
| **桌面 PR ok？** | **条件通过**：CRITICAL 播控/定时停/空态/双设置/收藏封面可合；下列 Known 不挡合 PR，但未宣称产品可发版 |

**不做发版。** 安卓仍 TBD（见下）。

---

## 修前失败（摘自 REVIEW-desktop-wip）

| id | 修前 | 证据 |
|---|---|---|
| D-PLAYER-03 | 切 720p → 英文 `Index was out of range` | A12/A13 |
| D-SET-02 | 定时停 15 分后 UI 卡死 | A16 |
| D-SEARCH-02 | `zzzzzqqq` 仍「搜索到 6 部」且无空态卡 | A17 |
| D-FAV-02 | 空态仅 Hint | A08 |
| 重复设置 | 侧栏+顶栏双设置 | A11 |
| D-FAV-01 | 收藏灰「封面」+ 数字 ID | A08/A18 |
| 状态栏串台 | 底栏残留首页计数 | A17 |

修前总评：**不通过。**

---

## 修后 F01–F09（截图自审）

| id | 结论 | 证据 | 说明 |
|---|---|---|---|
| F01 顶栏无双设置 | **过** | F01 | 仅搜索 / 隐藏继续听 / 刷新；设置在侧栏 |
| F02 首页推荐 | **过** | F02 | 真封面网格 |
| F03 清晰度 | **过** | F03 | 可切到 720p，无英文 Index 盖屏 |
| F04 倍速 | **过** | F04 | 1.5x，播控可用 |
| F05 定时芯片 | **过** | F05 | 关/15/30/60 芯片；倒计时文案 |
| F05b 定时后导航 | **过** | F05b | 选定时后仍能点剧场（修前卡死） |
| F06 搜索空态 | **过** | F06 | 真 0 结果出「没有找到」卡片；弱相关命中如实显示（SDK） |
| F07 收藏 | **过** | F07 | 空态卡片「去推荐选剧」；有项时封面/标题（batch enrich） |
| F08 历史 | **过** | F08 | 真封面标题；可续播路径 |
| F09 集数文案 | **过** | F09 | 不再「第N集 · 第N集」加倍 |

---

## 残差 / Known（不挡合 PR，不宣称发版）

| 项 | 状态 | 说明 |
|---|---|---|
| 进收藏/历史后导航卡死 | **已修（代码）** | FIXES §9：`_navSync` + ShowPage 不 await 库刷新 + 进度 timer 去 async void；单测 `ShowPage_history_favorites_does_not_await_network`。**尚未用本提交再跑一轮 GUI 截图**（本回合只交代码+REVIEW）。 |
| 隐藏继续听唤回黑窗 | **仍 open** | A10 / D-BG-01；与本 PR 无关，另开 |
| SDK 乱搜弱相关 | **仍 open / 上游** | 客户端如实显示；不伪造空结果 |
| 安卓竖滑/全功能截图 | **TBD** | `feature-audit-20261106/android/` 与 `feature-review-20261106/android/` 有部分帧；未纳入本桌面终评的 PR-ok 门禁 |

---

## 对成熟产品（红果 / 抖音 PC）

- 播控：倍速/选集/清晰度 **修后可用**，不再甩 CLR。
- 定时停：芯片化，对齐 Android；不再卡死壳。
- 空态：搜索 0 结果 / 收藏空 有「原因+主操作」。
- 桌面壳：侧栏+顶搜索方向对；设置单入口。
- 仍弱于成熟产品：搜索相关性、隐藏唤回、安卓体验未在本 PR 收口。

---

## Verdict

- **合 PR（desktop fix）: OK** — CRITICAL/HIGH 截图已过；导航卡死残差有根因修复+回归单测，无 Release。
- **发版 / 给用户 zip: NOT OK** — 用户明确不要发版本；隐藏唤回与 SDK 搜索、安卓仍未完。
- **下一步（非本提交）:** 用本分支再跑一轮 GUI（收藏→历史→侧栏连点）确认卡死不再复现；另跟隐藏唤回与安卓。

---

## Android（audit B 组 + ClearKey/封面修复）

对照：红果竖滑首页、剧场九宫格真封面、播控无 DRM 黑话。证据：`android/B01`–`B06`；说明见 `android/NOTES.md`。

| id | 修前截图结论 | 证据 | 本 PR 代码 | 合入后仍欠 |
|---|---|---|---|---|
| B01 首页竖滑推荐 | **过**（沉浸单列+真封面） | B01 | 无改 | — |
| B02 上滑下一推 | **过** | B02 | 无改 | — |
| B03 剧场九宫格 | **不过** — 标题有、封面全灰占位 | B03 | HEIC→PNG MethodChannel + CoverImage | 需重装 APK 复拍；API&lt;28 / 无 HEIF 编解码仍可能灰（NOTES） |
| B04 搜索空态 | 有帧 | B04 | 无改 | — |
| B05 搜索结果 | 有帧 | B05 | 无改 | — |
| B06 播放器 | **不过** — 黑屏 + `受保护流 (尝试 ClearKey/decryption_key)` | B06 | silent ClearKey UX；友好失败文案 | 需重装后确认 jargon 消失；真解密失败仍可能黑屏但文案友好 |

### Android verdict（相对成熟短剧 App）

- **修前（B06/B03）不通过 PR-ok 门禁**：播放器甩 ClearKey 技术串；剧场封面不可用。
- **本 PR 代码**：ClearKey **silent**（对齐 PR #25 意图并去掉残留「解密」话术）；剧场 HEIC 走系统 BitmapFactory（API 28+）。
- **仍不宣称可发版 / 不发 Release**：缺修后安卓复拍；解密失败黑屏、低 API HEIC 仍为 Known。

**未发 GitHub Release / 未出 zip。**
