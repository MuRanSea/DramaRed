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

## 页面（产品约定）

| 路由 | 说明 |
|---|---|
| 首页 | 顶栏仅「推荐」+ 搜索；竖滑换剧；点进播放页 |
| 搜索 | 顶栏「推荐」旁进入；结果点进播放 |
| 剧场 | 三列瀑布流封面；点进播放 |
| 播放页 | 竖屏沉浸；上滑下一集 / 下滑上一集；播完可自动下一集；预加载下一集；清晰度 / 倍速 / 选集 / 收藏 |
| 我的 | 历史 + 收藏（点进续播）；设置入口（含定时停播、后台继续听） |

底栏为「首页 / 剧场 / 我的」。不做商城、不做下载。定时停播不在播放页。

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

- 清晰度、倍速、选集、收藏（控件在播放页）
- 上滑下一集、下滑上一集；播完可自动下一集
- 预加载下一集（解析下一集地址并用待机 Player 打开）
- 后台继续听（切后台不主动 pause + `wakelock_plus`，设置在「我的」）
- 定时停播在「我的 → 设置」（15/30/45/60 分钟），不在播放页

单测：`cd apps/android && flutter test`

> 模拟器 guest 无出网时无法拉真实流；逻辑与 UI 以单测 + analyze 验证。Host daemon API 见 `docs/smoke-artifacts/host-api-smoke.md`。
