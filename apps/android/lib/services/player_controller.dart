/// media_kit 播放控制占位。
/// 预留：ClearKey、后台音频、倍速、自动连播、定时停止。
class PlayerController {
  Future<void> open(Uri url, {String? clearKey}) async {
    // TODO: Player() + Media(url) ；若有 clearKey 再配 DRM/ClearKey
    throw UnimplementedError('PlayerController.open');
  }

  Future<void> setRate(double rate) async {}

  Future<void> stop() async {}

  Future<void> dispose() async {}
}
