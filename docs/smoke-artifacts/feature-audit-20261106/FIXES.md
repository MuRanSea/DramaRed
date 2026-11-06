# Feature-audit fixes (2026-11-06 Asia/Shanghai)

Branch work against desktop bugs found while capturing `feature-audit-20261106` on `main@95c0e24`. **No GitHub Release / no zip.**

## CRITICAL

### 1. 清晰度切换 `IndexOutOfRange`
- **Bug:** Selecting 清晰度 (e.g. 自动→720p) showed English `操作失败: Index was out of range… (Parameter 'index')` on poster overlay + status bar; playback path aborted.
- **Cause:** `OnQualityChanged` awaited `PlayEpisodeAsync` → `FillQualityBox` which `Items.Clear()` / re-indexed the same ComboBox **re-entrantly inside SelectionChanged**. Avalonia ItemCollection threw `ArgumentOutOfRangeException`.
- **Fix:** Rebuild quality list via `ItemsSource` (no live `Clear`/`Items[i]`); defer quality switch with `Dispatcher.UIThread.Post`; wrap rebuild so it never crashes playback; map index exceptions to Chinese `操作失败：切换失败，请重试`.

### 2. 定时停 ComboBox freezes UI
- **Bug:** After choosing 定时停 15分, sidebar/other clicks stopped until process restart.
- **Cause:** `DispatcherTimer.Tick` used `async void` and reset `StopAfterBox.SelectedIndex` (re-entrant SelectionChanged). Avalonia ComboBox popup on Linux also left input stuck.
- **Fix:** Replace timer ComboBox with **chip buttons** (关/15/30/60, matches Android). Sync `Tick` only; pause on a posted `FinishStopTimerAsync`. `TimerHint` still shows `定时停止倒计时 MM:SS` then `定时停止已触发`.

### 3. Search false “empty” + missing empty card
- **Bug:** Query `zzzzzqqq` returned 「搜索到 6 部」 unrelated hits; true zero-result UI was Hint-only.
- **Fix:** When `Count==0` show `SearchEmpty` card（没有找到相关短剧 + 换个词试试）. When `Count>0` show results honestly (weak relevance is upstream SDK — documented here, not faked empty). Status bar follows search hint.

## HIGH

### 4. Favorites empty state
- **Fix:** `FavoritesEmpty` Border + primary CTA「去推荐选剧」, same pattern as `HistoryEmpty`.

### 5. Duplicate Settings
- **Fix:** Removed top-bar「设置」button; keep sidebar「设置」per `docs/desktop-ui.md` (settings in left nav; top bar = search + 隐藏继续听 + 刷新).

### 6. Episode text doubling
- **Bug:** `第 N 集 · 第N集` / preload `第 56 集 · 第56集`.
- **Fix:** `EpisodeItem.ListLabel` skips Title when it already matches `第\s*\d+\s*集`.

### 7. Stale status bar
- **Fix:** `UpdateStatusBarForPage` on every `ShowPage`; search/history/favorites refresh also refresh status when that page is current.

### 8. Covers/titles on favorites/history
- **Fix:** Daemon `GET /api/v1/series/batch?ids=` via openhongguo `GetSeriesBatch`; UI `SeriesBatchAsync` + `EnrichSeriesAsync` before building favorites/history rows.

## Tests
- `dotnet test apps/desktop/ui.Tests` — ListLabel, SearchEmpty, FavoritesEmpty, top-bar settings removal, existing suite.
- `go test ./...` under `apps/desktop/daemon` when daemon touched.

## Known follow-ups
- Hide/restore blank window (if still reproducible) — separate from this PR.
- SDK search relevance for nonsense queries — client cannot invent empty without lying; optional client-side relevance filter later.
