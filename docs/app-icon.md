# DramaRed 应用图标方案

> 一版主稿，已尽量落入 Android mipmap 与 Windows `.ico`。确认前可随时换稿。

## 概念

- 名称联想：**Drama**（竖屏短剧）+ **Red**（强调色）。
- 图形：深炭黑圆角底 + 霓虹红「竖屏手机框」+ 中央播放三角 + 两侧胶片点。
- 风格：扁平、高对比、少字，适合小尺寸识别。

## 主稿文件

| 文件 | 说明 |
|---|---|
| [wireframes/icon/dramared-icon-master.png](./wireframes/icon/dramared-icon-master.png) | 1024×1024 主 PNG |
| [wireframes/icon/dramared-icon-master.jpg](./wireframes/icon/dramared-icon-master.jpg) | 生成原图 |
| [wireframes/icon/app-icon-512.png](./wireframes/icon/app-icon-512.png) | 预览 |
| [wireframes/icon/app.ico](./wireframes/icon/app.ico) | 多尺寸 ICO 备份 |

## 已落入工程资源

| 端 | 路径 | 状态 |
|---|---|---|
| Android | `apps/android/android/app/src/main/res/mipmap-*/ic_launcher.png` | 已替换（mdpi→xxxhdpi） |
| Desktop | `apps/desktop/ui/Assets/app.ico` | 已写入；`DramaRed.UI.csproj` 增加 `ApplicationIcon` |

## 下一步（确认图标后再做）

1. Android adaptive icon（`mipmap-anydpi-v26` foreground/background 分层），避免圆角被系统再裁。
2. 通知栏小图标（单色 silhouette）。
3. Windows 安装包 / 快捷方式沿用 `Assets/app.ico`；macOS 另出 `.icns`（跨平台后续）。
4. 若你要换配色或加字标「剧」，在主稿上改一版再批量导出。
