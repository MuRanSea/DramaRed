# RUN — feature audit 2026-11-06 (Asia/Shanghai)

**Do not** package Windows zip / create GitHub Release / ask user to download.

## Current process state (box, ~23:13 CST)

| 组件 | 状态 |
|---|---|
| daemon | **RUNNING** `pid=1031523` · `127.0.0.1:17890` · health `{"ok":true,"sdk":"openhongguo@v0.2.0"}` · data dir `docs/smoke-artifacts/feature-review-20261106/desktop/daemon-data2` · device `apps/desktop/daemon/anonymous.json` |
| Desktop UI | **RUNNING** `pid=1081993` · `./DramaRed.UI` · cwd `apps/desktop/ui/bin/Release/net10.0/linux-x64` · `DISPLAY=:3` · window id `4194319` · title `DramaRed` · geometry `1360x860` @ `(10,58)` |
| git | `main` @ `95c0e24` (timeout Chinese hard) · already up to date with origin |
| Android emulator | **RUNNING** headless `dramared_api35` · adb `emulator-5554` · package `com.dramared.app` installed |
| adb path | `/home/box/sdk/android/platform-tools/adb` (not on default PATH) |

## Attach Desktop GUI (parent / desktop subagent)

```sh
export DISPLAY=:3
# focus existing window
xdotool windowactivate 4194319
# or relaunch if dead:
cd /workspace/DramaRed/apps/desktop/ui/bin/Release/net10.0/linux-x64
./DramaRed.UI
```

Screenshots → `/workspace/DramaRed/docs/smoke-artifacts/feature-audit-20261106/desktop/`

Rebuild if code changes:

```sh
cd /workspace/DramaRed/apps/desktop/ui
dotnet build -c Release -r linux-x64 --self-contained false
# then kill old UI and relaunch from bin/Release/net10.0/linux-x64
```

Daemon only if needed:

```sh
# already listening; only restart if health fails
curl -sS http://127.0.0.1:17890/health
# rebuild: cd apps/desktop/daemon && go build -o /tmp/drama-daemon ./cmd/drama-daemon
```

## Android GUI capture (emulator available)

```sh
export PATH="/home/box/sdk/android/platform-tools:$PATH"
adb devices -l   # expect emulator-5554
adb shell am start -n com.dramared.app/.MainActivity
# or flutter APK:
# adb install -r /workspace/DramaRed/apps/android/build/app/outputs/flutter-apk/app-x86_64-debug.apk
adb exec-out screencap -p > /workspace/DramaRed/docs/smoke-artifacts/feature-audit-20261106/android/NN-name.png
```

Emulator is **headless** (`-no-window`); use `adb screencap` / `uiautomator` for evidence. Live GUI mirror needs scrcpy or box desktop viewing — not required if screencaps are clear.

## Restart cheat-sheet

```sh
# stop UI only
kill 1081993
# stop daemon only (careful: drops local history/fav DB for that data dir)
# kill 1031523
```

## Probe notes (executor, not checklist pass)

- `refs/D-CHROME-probe-ffmpeg.png`: current UI top bar has search+actions only (no in-app DramaRed/番茄叠标题). Search idle main area is empty except page title/hint — supports D-SEARCH-02 gap. Status bar still showed「共 8 部」while on search idle (stale status possible UX nit).
