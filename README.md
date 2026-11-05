# DramaRed

个人学习 / 自用的短剧客户端骨架（Android + Desktop 跨平台）。

> **可运行路径**：Android 书城/搜索/播放体验/历史收藏已接；Desktop Avalonia 已联调 daemon + libmpv（独立窗口出画）。模拟器 guest 无出网时 OHG 需 host/文档说明。

## 功能（目标）

- 搜索短剧
- 推荐 / 书城
- 分集列表与换集
- 在线播放（清晰度、倍速、自动连播）
- 播放历史 / 续播
- 收藏
- 定时停止
- 后台 / 隐藏继续听
- **不做下载**

## 技术栈

| 端 | 方案 |
|---|---|
| Android | Flutter + [openhongguo](https://pub.dev/packages/openhongguo) `0.2.0` + [media_kit](https://pub.dev/packages/media_kit)（ClearKey / 后台听预留） |
| Desktop | Avalonia (.NET) UI + Go 业务进程（[openhongguo Go SDK](https://pkg.go.dev/github.com/beilunyang/openhongguo/sdk) `v0.2.0`）+ libmpv |
| SDK 锁定 | **openhongguo v0.2.0**（Flutter pub / Go module 均锁此版本） |

## 仓库结构

```
apps/android/          Flutter Android 客户端骨架
apps/desktop/ui/       Avalonia UI 骨架
apps/desktop/daemon/   Go 本地 API 进程（封装 openhongguo）
apps/desktop/README.md Desktop 联调说明（Linux/Windows/macOS）
docs/architecture.md   两端架构与模块边界
```

## 免责声明

本项目基于非官方 SDK [openhongguo](https://github.com/beilunyang/openhongguo)，用途仅限个人学习与研究。以下免责声明摘自 / 对齐 openhongguo 仓库：

> **免责声明**
>
> 请以学习为目的使用本仓库。
>
> 本仓库的所有内容仅供学习和参考之用，禁止用于商业用途。任何人或组织不得将本仓库的内容用于非法用途或侵犯他人合法权益。
>
> 本仓库所涉及的接口分析与调用技术仅用于学习和研究，不得用于对其他平台进行大规模数据采集或其他非法行为。
>
> 对于因使用本仓库内容而引起的任何法律责任，本仓库不承担任何责任。使用本仓库的内容即表示您同意本免责声明的所有条款和条件。
>
> 短剧等媒体内容的版权归原权利人所有；本项目不提供下载功能，也不主张对第三方内容享有任何权利。

完整原文见：[beilunyang/openhongguo README — 免责声明](https://github.com/beilunyang/openhongguo#免责声明)。

## 如何开发

### 前置工具

| 工具 | 用途 | 备注 |
|---|---|---|
| Flutter (stable) + Android SDK + JDK 17 | `apps/android` | box 已装 Flutter/JDK/Android SDK；`pub get` / `analyze` 通过 |
| Go ≥ 1.22 | `apps/desktop/daemon` | 已锁 openhongguo `@v0.2.0`；curl 冒烟通过 |
| .NET 10 SDK | `apps/desktop/ui` Avalonia | box 已装 10.0.403；TFM `net10.0`；`linux-x64` build 通过 |
| libmpv | 播放器 | Linux/macOS 用系统库；Windows 可选 DLL |

### Android

```sh
cd apps/android
flutter pub get
flutter run
```

页面：`Home`（书城）/ `Search` / `Player`（清晰度·倍速·连播·定时停·后台听）/ `Favorites` / `History`（续播）。

### Desktop（Linux / Windows / macOS）

见 [`apps/desktop/README.md`](apps/desktop/README.md)。

简要：先启动 Go daemon（默认 `http://127.0.0.1:17890`），再启动 Avalonia UI。播放经 `LibMpvMediaPlayer.OpenAsync`（Linux/macOS 系统 libmpv；Windows 可选 DLL）；无库时回退 `NullMediaPlayer` 不崩。

### Go daemon 单独跑

```sh
cd apps/desktop/daemon
go run ./cmd/drama-daemon
# 健康检查
curl -s http://127.0.0.1:17890/health
```

## Box 环境

云端 box 工具链与阻塞见 [`docs/box-env.md`](docs/box-env.md)。

## 许可与用途

个人学习 / 自用。请遵守 openhongguo 与各上游依赖的许可证及免责声明。禁止商业使用。
