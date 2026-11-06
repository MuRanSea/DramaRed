# Android feature-audit notes — 2026-11-06/07 (Asia/Shanghai)

Evidence under this folder: `B00`–`B06` (+ later frames). **No GitHub Release / no zip.**

## B06 player — ClearKey jargon (FAIL → code fix)

Screenshot `B06-player.png` shows black player with status:

`受保护流 (尝试 ClearKey/decryption_key)`

That string was the **pre–PR #25** user-facing status. PR #25 (`fd506f1`) already replaced it with quieter copy, but audit APK/screenshots still captured the old build, and residual 「此集受保护，暂无法解密」 still leaked DRM wording.

**Fix on PR #29 branch (this pass):**

- `_applyResultMeta` never surfaces 「受保护流」「ClearKey」「decryption_key」「解密」; protected streams stay **silent** (debugPrint only). Status = `缓冲中…` then `播放中` when engine reports playing.
- `PlayerController.applyContentKey` still best-effort sets `demuxer-lavf-o=decryption_key=…` internally.
- Engine `stream.error` and load failures map through `StatusPane.friendlyPlaybackStatus` / `playFailedFriendly` → `暂时无法播放，请换一集或稍后重试`.
- Unit tests scrub ClearKey / 受保护 jargon in `status_pane_test.dart`.

**Remaining gap:** encrypted episodes may still black-screen if demuxer cannot decrypt (upstream/key). UX should now be friendly Chinese only — **re-screenshot after rebuild** to confirm B06 jargon gone.

## B03 theater — grey cover placeholders

`B03-theater.png`: titles + episode counts OK; every cell shows grey `broken_image` / movie placeholder.

Root cause (not empty enrich): OHG `cover_url` is almost always **signed `.heic`** (`image/heic`). Desktop already converts via ffmpeg (`CoverLoader`). Flutter `Image.network` often cannot decode HEIC → errorBuilder grey tiles. Prior `feature-review` `REVIEW-03-theater.png` (~3 MB) proves covers *can* paint when decode works; B03 is the HEIC/decode failure path (or early shot before decode).

**Fix attempted (easy):**

- MethodChannel `com.dramared.app/covers` / `decodeToPng` using Android `BitmapFactory` (HEIF **API 28+**).
- `CoverImage` routes `.heic`/`.heif` URLs through download + channel → `Image.memory`; JPEG/WebP stay on `Image.network` with loading placeholder.
- `SeriesTile` reuses `CoverImage`.

**Env limits to document:**

- Emulators / devices **API &lt; 28** or without HEIF codecs still show placeholders (document, not a URL/enrich bug).
- CDN signature is path-bound — cannot rewrite `.heic`→`.jpeg` client-side (403 `x_signature auth failed`).
- Full ffmpeg-on-device path not added (heavy); desktop remains the reference HEIC converter.

## Other Android gaps (honest, not fixed this pass)

- Player black frame when decrypt truly fails (friendly copy only).
- No re-capture of B03/B06 after this fix in this commit (needs rebuild + emulator).
- Favorites / settings / speed / definition interactive shots still thinner than mature apps (see parent REVIEW).
