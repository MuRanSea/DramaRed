# Host API smoke（daemon / openhongguo）

- result: **PASS**（2026-11-05 Asia/Shanghai，box）
- health: `openhongguo@v0.2.0` / `drama-daemon`
- search `短剧` → 5 hits；首部 `初尝玫瑰！` id `7695625941778697241`
- episodes → 454；首集 `第1集` id `7695629314057849880`
- playback → `drmProtected=true`，带 `contentKey`，多清晰度 streams（含 360p URL）

> 模拟器 eth0 无出网时，用本记录证明 SDK/daemon 链路；出画见 media_kit local smoke。
