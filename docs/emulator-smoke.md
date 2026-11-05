# Android 模拟器端到端验播（issue #3）

## 目标

验证：搜索 → 分集 → playback → media_kit 出画/播放信号。

## 两种模式

### A. OHG 全链路（需模拟器出网）

```sh
flutter build apk --debug --split-per-abi
./scripts/emulator_e2e.sh
```

box 上部分嵌套/TCG AVD **无可用 eth0 出网**（`Active default network: none`）。此时 OHG 模式会 `FAIL`/`TIMEOUT`，属环境阻塞，不是业务逻辑回归。

### B. media_kit 本地出画（推荐，不依赖 guest 出网）

```sh
SMOKE_MODE=local SMOKE_SECONDS=20 ./scripts/emulator_e2e.sh
# 等价：push sample.mp4 后 smoke_url=file:///data/local/tmp/sample.mp4
```

期望：`PASS media_kit_local_ok`（含 `video_width>0` / `playing=true`）。

### B2. media_kit HTTP（adb reverse，可选）

证明播放器在模拟器上能出画：

```sh
# 终端 1：托管 sample.mp4
cd docs/smoke-artifacts && python3 -m http.server 8765

# 终端 2
adb reverse tcp:8765 tcp:8765
SMOKE_URL=http://127.0.0.1:8765/sample.mp4 SMOKE_SECONDS=12 ./scripts/emulator_e2e.sh
```

期望 logcat：`PASS media_kit_local_ok`。

### C. Host API 半链路（daemon）

在 box 主机跑 Go daemon，验证 openhongguo 搜索→分集→playback（含 DRM contentKey）：

见 `docs/smoke-artifacts/host-api-smoke.md`。

## Intent extras

| extra | 含义 |
|---|---|
| `smoke_auto` | 进入 SmokePage |
| `smoke_query` | 搜索词 |
| `smoke_seconds` | 观察秒数 |
| `smoke_url` | 非空则跳过 ohg，直接 `Media(url)` |

判定前缀：`[DramaRedSmoke]` → `PASS …` / `FAIL …`。
