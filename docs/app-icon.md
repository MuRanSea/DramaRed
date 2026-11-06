# DramaRed 应用图标方案

> 按反馈采用 **小番茄** 风格。已更新 master / Android mipmap / Windows `app.ico`。

## 概念

- 一只圆润小番茄（红果联想）+ 绿色蒂，深炭黑圆角底。
- 扁平可爱、少细节，小尺寸仍可辨。
- **不再使用**「竖屏框 + 播放三角」旧稿。

## 主稿

| 文件 | 说明 |
|---|---|
| [wireframes/icon/dramared-icon-master.png](./wireframes/icon/dramared-icon-master.png) | 1024×1024 主 PNG（小番茄） |
| [wireframes/icon/dramared-icon-tomato.png](./wireframes/icon/dramared-icon-tomato.png) | 同主稿副本 |
| [wireframes/icon/app-icon-512.png](./wireframes/icon/app-icon-512.png) | 预览 |
| [wireframes/icon/app.ico](./wireframes/icon/app.ico) | 多尺寸 ICO |

## 已落入工程

| 端 | 路径 |
|---|---|
| Android | `apps/android/android/app/src/main/res/mipmap-*/ic_launcher.png` |
| Desktop | `apps/desktop/ui/Assets/app.ico`（`ApplicationIcon`） |

## 下一步（确认后）

1. Android adaptive icon 分层（前景番茄 / 背景深色）。
2. 通知栏单色剪影。
3. macOS `.icns`。
