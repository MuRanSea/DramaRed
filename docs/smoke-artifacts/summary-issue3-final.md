# Issue #3 模拟器验播结论（2026-11-05 Asia/Shanghai）

## 结果总览

| 路径 | 结果 | 说明 |
|---|---|---|
| media_kit 本地出画 | **PASS** | `file:///data/local/tmp/sample.mp4` → `playing=true` `video_width=320` `PASS media_kit_local_ok` |
| Host daemon API | **PASS** | search→episodes→playback（含 DRM contentKey），见 `host-api-smoke.md` |
| Emulator OHG 全链路 | **阻塞** | AVD eth0 无出网（`Active default network: none`）；TCG 可启动但 guest 无法访问公网 |

## media_kit PASS 摘录

```
[DramaRedSmoke] mode=direct_url url=file:///data/local/tmp/sample.mp4
[DramaRedSmoke] playing=true
[DramaRedSmoke] video_width=320
[DramaRedSmoke] observe_done sawPlaying=true width=320 posMs=2769 durMs=3023
[DramaRedSmoke] PASS media_kit_local_ok
```

## 复现（本地出画）

```sh
adb push docs/smoke-artifacts/sample.mp4 /data/local/tmp/sample.mp4
adb shell am start -n com.dramared.app/.MainActivity \
  --ez smoke_auto true \
  --es smoke_url 'file:///data/local/tmp/sample.mp4' \
  --ei smoke_seconds 20
adb logcat | grep DramaRedSmoke
```

或：`SMOKE_URL=file:///data/local/tmp/sample.mp4 ./scripts/emulator_e2e.sh`（需先 push）。
