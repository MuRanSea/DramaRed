# Android feature-audit notes — R 组复拍（Asia/Shanghai 2026-11-07）

Evidence: `R01`–`R08` under this folder. **No GitHub Release / no zip.**

Built from branch `fix/desktop-feature-audit-bugs-20261106` @ `13f5968` (silent ClearKey + HEIC CoverImage).  
APK: `apps/android/build/app/outputs/flutter-apk/app-x86_64-debug.apk` (rebuilt 2026-11-07 ~00:13 CST), installed on `emulator-5554` (API 35, 1080×2400).

**Discard for review:** `B10-mine-history.png` / `B11-favorites.png` / `B12-settings.png` — tomato splash / invalid; do not use.

---

## R-shot pass/fail (honest)

| id | 结论 | 证据 | 说明 |
|---|---|---|---|
| R01 首页沉浸推荐 | **过（内容） / 封面弱** | R01-home | 推荐单列有标题/简介/观看 CTA；封面未画出（灰底+播钮）。无 ClearKey 黑话。 |
| R02 上滑换剧 | **过（换剧） / 封面炸** | R02-home-swipe | 滑到另一部（重生囤百亿…）；画面红 X + `Exception: Could not decompress image.`（HEIC 路径失败泄露 Exception 文案）。 |
| R03 剧场九宫格 | **不过（封面）** | R03-theater | 标题/集数有；每格灰底或 decompress Exception。HEIC 未成。 |
| R04 搜索结果 | **过（结果） / 封面灰** | R04-search | 有结果网格+标题；封面全灰占位。输入被 adb 截成 `ong`（仍出结果）。 |
| R05 播放器 | **过（ClearKey 门禁）** | R05-player | 黑屏但状态 **「播放中」**；无「受保护流 / ClearKey / decryption_key / 解密」。有选集/倍速/清晰度芯片与收藏。真画面是否出取决于上游解密，本帧未出画。 |
| R06 我的·历史 | **过** | R06-mine-history | 真「我的」页（非 splash）；历史两项+进度；封面灰占位。 |
| R07 收藏 | **过** | R07-favorites | 「收藏」加粗；三部收藏（全60/63/48集）；封面灰占位。 |
| R08 设置 | **过** | R08-settings | 定时停播芯片 + 后台继续听 + 自动连播；文案完整。 |

---

## ClearKey jargon

**Gone on R05** after `13f5968` rebuild. OCR / 目视均无 ClearKey / decryption_key / 受保护流。  
残差：加密集仍可能黑屏，但只显示「播放中」或友好失败（本帧为播放中）。

## Theater / cover HEIC

**仍灰。** 根因不止「无 HEIF codec」：

- Emulator API **35**（满足 BitmapFactory HEIF API≥28 门槛）。
- logcat：`[CoverImage] heic decode failed: HandshakeException` — Dart `HttpClient` 拉签名 CDN `.heic` TLS 握手失败；频道解码未跑到。
- 失败时部分格子走 `Image.memory`/`Image.network` 错误路径，用户可见 `Exception: Could not decompress image.`（R02/R03）——不合理，应对齐灰占位、不甩 Exception 串。

旧 B01（修前 Image.network、个别非 HEIC 或不同 TLS 路径）曾有真封面；本 R 组在 HEIC CoverImage + HandshakeException 下全灰。

## 其它诚实缺口

- 搜索 adb `input text` 易丢首字符；应用内搜索本身可用。
- 从播放页连按返回易出 App 到桌面（曾误拍 launcher 当 R06–R08）；本 R06–R08 为重新进「我的」后的真页。
- uiautomator dump 在软模拟器上常 TIMEOUT；坐标 + OCR 校验。

**未发版。**
