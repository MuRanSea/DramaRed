# Box 环境状态（云端）

记录 DramaRed 在 `/workspace` box 上的工具链与阻塞点。时区：Asia/Shanghai。

## .NET / Avalonia

| 项 | 值 |
|---|---|
| .NET SDK | **10.0.403**（官方正式版已可装；`$HOME/.dotnet`） |
| Avalonia | **12.1.2** |
| UI TFM | **net10.0** |
| RIDs | `linux-x64;win-x64;osx-x64;osx-arm64` |
| 验证 | `dotnet build -c Release -r linux-x64` 通过 |

## Desktop 路径

原 `apps/windows` 已重命名为 **`apps/desktop`**（跨平台，不绑定 Win32）。

播放：`IMediaPlayer` / `LibMpvMediaPlayer`（探测系统 libmpv）/ `NullMediaPlayer`；Windows `libmpv-2.dll` 仅可选。

## libmpv（Linux）

| 项 | 值 |
|---|---|
| 包 | `libmpv2` **0.40.0-3**（`ii` 已安装） |
| so | `/usr/lib/x86_64-linux-gnu/libmpv.so.2` |
| 备注 | 官方 apt 镜像不可用时用 Debian snapshot；个别 deb 需 curl 补拉；`fuse3` 配置用 `--force-confold` |

## Android 工具链

| 项 | 值 |
|---|---|
| Flutter | 3.35.7（`$HOME/sdk/flutter`） |
| JDK | 17 |
| Android SDK | `$HOME/sdk/android`（platform-tools、emulator 37、system-images;android-35;google_apis;x86_64） |
| AVD | `dramared_api35`（Pixel 6 / API 35） |

### 模拟器阻塞 / 冒烟

- `/dev/kvm` 可用；`box` 已加入 `kvm` 组；`emulator -accel-check` 报 KVM usable。
- 实际 **`-accel on`（KVM）启动后 qemu CPU 接近空闲，adb 长期 `offline`**——疑似嵌套虚拟化不稳定。
- **`-accel off`（TCG）**：qemu 高 CPU（~100%），adb 可变为 `device`，但冷启动到 `sys.boot_completed=1` 极慢（十余分钟级）。
- 工具链 + system image + AVD `dramared_api35` 已装齐；APK 冒烟视 boot 是否在本轮完成。
- 已有 debug APK 构建能力（`flutter build apk --debug`）。

## Go daemon

`apps/desktop/daemon`，module path `.../apps/desktop/daemon`，openhongguo `v0.2.0`。

### APK 冒烟（本轮）

- TCG 下 adb 最终为 `device`；`pm path android` 可用，但 `sys.boot_completed` 长时间未到 `1`。
- `adb install` / `pm install` 在 PackageManager 未完全就绪时失败（`PackageManagerInternal.freeStorage` NPE / Broken pipe）。
- Debug APK 已成功构建：`apps/android/build/app/outputs/flutter-apk/app-debug.apk`（~208MB，不入库）。
- 结论：工具链+AVD+模拟器进程可起；完整 APK 安装冒烟受冷启动/嵌套环境阻塞，需等 boot 完成或换真机。
