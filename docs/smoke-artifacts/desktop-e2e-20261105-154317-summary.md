# DramaRed Desktop Linux e2e — 2026-11-05 15:43 CST (Asia/Shanghai)

- **repo**: MuRanSea/DramaRed
- **commit**: `4e94a1e` (main)
- **DISPLAY**: `:3`
- **artifacts**: `docs/smoke-artifacts/desktop-e2e-20261105-154317/`

## Build

| Target | Result |
|---|---|
| Go daemon (`apps/desktop/daemon`) | **PASS** → `/tmp/drama-daemon` |
| Avalonia UI `dotnet build -c Release -r linux-x64` | **PASS** → `bin/Release/net10.0/linux-x64/DramaRed.UI.dll` |

## Daemon curl smoke

| API | Result |
|---|---|
| `GET /health` | OK `service=drama-daemon` sdk openhongguo@v0.2.0 |
| `GET /api/v1/discover` | OK **9** items (first: 装穷提亲…) |
| `GET /api/v1/search?q=短剧` | OK **5** items |
| `GET /api/v1/series/{id}/episodes` | OK **80** eps (ep1 playable) |
| `GET /api/v1/episodes/{id}/playback` | OK **5** streams, DRM protected, **contentKey present** (32 hex), best **1080p** |

JSON dumps: `health.json` `discover.json` `search.json` `episodes.json` `playback.json`

## libmpv real playback e2e

- Backend: `libmpv ready (libmpv.so.2)`
- Opened real OHG playback URL + `decryption_key` / contentKey
- Position samples: `0.000s → 0.833s → 1.833s` then pause
- **PASS playing (position advanced)** — demux + decode progressing
- Audio: ALSA/JACK have **no sound card** on this box (`cannot find card '0'`) → **no audible output expected**; video/demux still advanced under `DISPLAY=:3` (VDPAU nvidia backend missing is non-fatal warning)
- CLI `mpv` not installed; skipped cross-check
- Log: `libmpv-play.log`

## Avalonia UI launch

- `timeout 12 dotnet …/DramaRed.UI.dll` under `DISPLAY=:3`
- Exit **124** (124 = timed out while still running = expected for smoke)
- Unhandled exception: **none**
- Log: `avalonia-launch.log`

## Overall

| Check | Status |
|---|---|
| Compile daemon + UI | PASS |
| API smoke | PASS |
| libmpv open + position advance (DRM URL) | PASS |
| Audio out | N/A (no ALSA device on box) |
| Avalonia start | PASS |

## Failure / limits

1. Box has no ALSA playback device — cannot verify speakers.
2. `Failed to open VDPAU backend libvdpau_nvidia.so` — warning only; software path used.
3. Guest/headless without DISPLAY would use `vo=null` (documented in `apps/desktop/README.md`).
