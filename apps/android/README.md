# DramaRed Android（Flutter）

## 依赖

- Flutter stable 3.35+ / Dart 3.9+
- Android SDK（API 24+；openhongguo 要求）
- JDK 17
- `openhongguo: 0.2.0`（锁定）
- `media_kit` + `media_kit_video` + `media_kit_libs_android_video`

## 在本仓库 box 上已验证

```sh
flutter pub get   # OK
flutter analyze   # No issues
```

`openhongguo` **不支持** Web / Linux desktop；业务 API 只能在 **Android/iOS** 真机或模拟器上跑通。

## 有设备时如何验证播放

1. 连接设备或启动模拟器：`flutter devices`
2. `cd apps/android && flutter run`
3. 流程：搜索 → 点进剧 → 选集 → `resolvePlayback` → media_kit 打开流
4. 受保护流会尝试 `demuxer-lavf-o=decryption_key=<hex>`（ClearKey 完整方案仍可能需后续加固）

## 页面

| 路由 | 说明 |
|---|---|
| Home | `discover()` 书城推荐 |
| Search | `search(q)` |
| Series | `listEpisodes` + 收藏 |
| Player | `resolvePlayback` + media_kit（清晰度/倍速 UI） |
| Favorites / History | SharedPreferences 本地存储 |

## 工程说明

已用 `flutter create --platforms=android` 对齐官方工程；`minSdk=24`，`applicationId=com.dramared.app`。

## openhongguo 依赖

因 pub 上 `openhongguo` 0.2.0 的 `android/build.gradle.kts` 未 apply Kotlin Android 插件导致
`flutter build apk` 失败，本仓库将 **API 锁定的 0.2.0** 以 path 形式 vendored 到
`packages/openhongguo`（见其中 `PATCHES.md`）。

## 构建结果（box）

```sh
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk （勿提交）
```

## 播放体验（issue #4）

Player 页支持：

- 清晰度切换（切换后尽量 seek 回原进度）
- 倍速 0.75 / 1.0 / 1.25 / 1.5 / 2.0
- 自动连播（需从分集页传入 `episodes`）
- 定时停止（15/30/45/60 分钟）
- 后台继续听（切后台不主动 pause + `wakelock_plus`）

单测：`flutter test test/player_controller_test.dart`

> 模拟器 guest 无出网时无法拉真实流；逻辑与 UI 以单测 + analyze 验证。Host daemon API 见 `docs/smoke-artifacts/host-api-smoke.md`。
