import 'package:media_kit/media_kit.dart';
import 'package:openhongguo/openhongguo.dart';

/// media_kit playback helper. ClearKey / decryption_key is best-effort.
class PlayerController {
  PlayerController() : player = Player();

  final Player player;

  /// Pick a stream preferring higher resolution; fall back to first with URL.
  static VideoStream? pickStream(Playback playback, {String? preferDefinition}) {
    final streams = playback.streams.where((s) => s.url.isNotEmpty).toList();
    if (streams.isEmpty) return null;
    if (preferDefinition != null && preferDefinition != '自动') {
      for (final s in streams) {
        final label = s.definition.isEmpty ? s.quality : s.definition;
        if (label.toUpperCase().contains(preferDefinition.toUpperCase())) {
          return s;
        }
      }
    }
    streams.sort((a, b) => b.height.compareTo(a.height));
    return streams.first;
  }

  Future<void> openPlayback(
    PlaybackResult result, {
    String? preferDefinition,
  }) async {
    final stream = pickStream(result.playback, preferDefinition: preferDefinition);
    if (stream == null) {
      throw StateError('no playable stream URL in playback model');
    }

    final key = result.contentKey?.key;
    if (key != null && key.isNotEmpty) {
      // Best-effort for cenc-aes-ctr via libmpv/ffmpeg lavf decryption_key.
      final platform = player.platform;
      if (platform is NativePlayer) {
        try {
          await platform.setProperty('demuxer-lavf-o', 'decryption_key=$key');
        } catch (_) {
          // May be unsupported depending on backend build.
        }
      }
    }

    await player.open(Media(stream.url));
  }

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> stop() => player.stop();

  Future<void> dispose() async {
    await player.dispose();
  }
}
