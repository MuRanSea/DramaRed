# DramaRed Android（Flutter）

## 依赖

- Flutter stable（建议 3.24+）
- Android SDK / emulator 或真机（API 24+，openhongguo 要求）
- `openhongguo: 0.2.0`（锁定）
- `media_kit` 系列（播放占位；ClearKey / 后台听未实现）

## 运行

```sh
flutter pub get
flutter run
```

若本环境未安装 Flutter，请在开发机安装后于本目录执行上述命令。

## 页面

| 路由 | 文件 | 状态 |
|---|---|---|
| Home | `lib/pages/home_page.dart` | 占位（书城/推荐入口） |
| Search | `lib/pages/search_page.dart` | 占位 |
| Player | `lib/pages/player_page.dart` | 占位（清晰度/倍速/连播 UI 壳） |
| Favorites | `lib/pages/favorites_page.dart` | 占位 |
| History | `lib/pages/history_page.dart` | 占位 |

## 关于手写骨架

本目录为在无 Flutter SDK 环境下手写的可识别骨架（含 `pubspec.yaml`、页面与 Android embedding 占位）。
在已安装 Flutter 的机器上，建议于本目录执行一次：

```sh
flutter create --project-name dramared --org com.dramared --platforms=android .
flutter pub get
```

以补齐 `ios/`（若需要）、gradle wrapper、图标等官方生成文件；注意保留现有 `lib/` 与锁定的 `openhongguo: 0.2.0`。
