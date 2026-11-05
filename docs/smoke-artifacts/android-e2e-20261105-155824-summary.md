# Android e2e smoke — 2026-11-05 (Asia/Shanghai)

**Repo:** MuRanSea/DramaRed @ `976f0ce` (main, after desktop e2e PR #17)  
**AVD:** `dramared_api35` (API 35, x86_64, TCG `-accel off`, often `-no-window`)  
**Artifacts:** `docs/smoke-artifacts/android-e2e-20261105-155824/`

## Verdict

| Step | Result |
|------|--------|
| `flutter build apk --debug --split-per-abi` | **PASS** |
| AVD boot / reuse | **PASS** (boot_completed=1) |
| `adb install` x86_64 APK | **PASS** |
| Launch `MainActivity` | **PASS** (task visible; Flutter Impeller + media_kit attach) |
| Guest outbound net (search / 书城 / OHG) | **BLOCKED** — `ping 8.8.8.8` → Network is unreachable |
| Local file:// smoke (`DramaRedSmoke` + sample.mp4) | **PARTIAL / TIMEOUT** — started `direct_url`, no `open_direct_done` / `playing=` / `PASS` |
| Host complementary | **PASS** — `flutter test` 9/9; drama-daemon `/health` + `/api/v1/discover` 8 items |

Overall: **APK build + install + process start OK.** Full OHG e2e and in-emulator local playback completion not verified on this run because guest has no outbound IP and the TCG emulator hit system ANRs that starved `player.open`.

## APK

| ABI | Path | Size |
|-----|------|------|
| **x86_64 (emulator)** | `apps/android/build/app/outputs/flutter-apk/app-x86_64-debug.apk` | **111M** (116353659 bytes) |
| arm64-v8a | `.../app-arm64-v8a-debug.apk` | 121M |
| armeabi-v7a | `.../app-armeabi-v7a-debug.apk` | 101M |

Installed package: `com.dramared.app` via streamed install → Success.

## What ran

1. Built debug split-per-abi on box Flutter 3.35.7.  
2. Reused then cold-restarted AVD after an earlier `am hang` freeze; BOOT_OK in ~3–4 min.  
3. Installed x86_64 APK; launched normal UI then smoke Intent:
   ```
   am start -n com.dramared.app/.MainActivity
     --es smoke_auto 1
     --es smoke_url file:///data/local/tmp/sample.mp4
   ```
4. Logcat (`logcat-relevant3.txt`):
   - Impeller OpenGLES  
   - `media_kit_libs_android_video attached`  
   - `[DramaRedSmoke] start observe=25s`  
   - `[DramaRedSmoke] mode=direct_url url=file:///data/local/tmp/sample.mp4`  
   - **No** `open_direct_done` / `playing=` / `PASS` / `FAIL` within ~8+ min → `LOCAL_SMOKE3=TIMEOUT`  
5. Screenshots show system ANR overlays (“Digital Wellbeing isn’t responding”, “Process system isn’t responding”), not app UI — TCG + system_server stress, not a DramaRed crash signature. Bluetooth `SIGABRT` noise in parallel.  
6. Guest eth0: no outbound → cannot exercise OHG search / bookstore / remote play inside guest.  
7. Host side (same box): `flutter test` All tests passed (9); `/tmp/drama-daemon` health ok, discover 8 items (`host-api.txt`).

## Known limits (this box)

- Emulator guest **no internet** → in-guest OHG e2e impossible; use host daemon / desktop e2e for API+playback path.  
- TCG without KVM is extremely slow; wellbeing/systemui ANRs and binder stalls are common; `uiautomator` / dumpsys often hang.  
- Prior healthier run (issue #3 era) recorded `media_kit_local_ok` PASS for the same local file:// path — see `docs/smoke-artifacts/summary-issue3-final.md`. This session did not re-obtain that PASS under load.  
- Do **not** use `adb shell am hang` on this AVD (freezes system_server).

## Play depth reached

1. App process up, Flutter engine + media_kit native libs loaded.  
2. SmokePage entered direct_url mode with `file:///data/local/tmp/sample.mp4`.  
3. Stuck inside / after `_controller.player.open(Media(url))` before `open_direct_done` log — **playback not confirmed**.  
4. Search / 书城 / episode play via OHG: **not attempted in guest** (no net).

## Artifact index

- `run.txt` — install/launch timeline + TIMEOUT markers  
- `logcat-relevant3.txt` — DramaRedSmoke / media_kit lines  
- `logcat-local{2,3}.txt.gz` — raw dumps  
- `ui-home.png` / `ui-smoke.png` — ANR overlays during stress  
- `flutter-test.txt`, `host-api.txt` — host complementary PASS  

## Follow-ups (optional)

- Re-run local smoke on a KVM/accelerated AVD or physical device for `PASS`.  
- Wire guest DNS/NAT or use `adb reverse` + host daemon base URL for in-app OHG e2e.  
