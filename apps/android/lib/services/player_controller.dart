import 'package:media_kit/media_kit.dart';
import 'package:openhongguo/openhongguo.dart';

/// media_kit playback helper. ClearKey / decryption_key is best-effort.
class PlayerController {
  PlayerController() : player = Player();

  final Player player;

  /// Pick a stream preferring [preferDefinition]; fall back to highest height.
  static VideoStream? pickStream(Playback playback, {String? preferDefinition}) {
    final streams = playback.streams.where((s) => s.url.isNotEmpty).toList();
    if (streams.isEmpty) return null;
    if (preferDefinition != null && preferDefinition != '自动') {
      for (final s in streams) {
        final label = streamLabel(s);
        if (label.toUpperCase().contains(preferDefinition.toUpperCase())) {
          return s;
        }
      }
    }
    streams.sort((a, b) => b.height.compareTo(a.height));
    return streams.first;
  }

  static String streamLabel(VideoStream s) {
    final d = s.definition.isEmpty ? s.quality : s.definition;
    return d.isEmpty ? '${s.height}p' : d;
  }

  /// Next playable episode after [currentId], or null.
  static Episode? nextEpisode(List<Episode> episodes, String currentId) {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexWhere((e) => e.id == currentId);
    if (idx < 0) return null;
    for (var i = idx + 1; i < episodes.length; i++) {
      if (episodes[i].id.isNotEmpty && episodes[i].playable) {
        return episodes[i];
      }
      // Some feeds mark playable=false incorrectly; still allow non-empty id.
      if (episodes[i].id.isNotEmpty) return episodes[i];
    }
    return null;
  }

  Future<void> openPlayback(
    PlaybackResult result, {
    String? preferDefinition,
    Duration? seekTo,
  }) async {
    final stream = pickStream(result.playback, preferDefinition: preferDefinition);
    if (stream == null) {
      throw StateError('no playable stream URL in playback model');
    }

    final key = result.contentKey?.key;
    if (key != null && key.isNotEmpty) {
      final platform = player.platform;
      if (platform is NativePlayer) {
        try {
          await platform.setProperty('demuxer-lavf-o', 'decryption_key=$key');
        } catch (_) {}
      }
    }

    await player.open(Media(stream.url));
    if (seekTo != null && seekTo > Duration.zero) {
      // Give demuxer a beat before seek on slow emulators.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        await player.seek(seekTo);
      } catch (_) {}
    }
  }

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> pause() => player.pause();

  Future<void> play() => player.play();

  Future<void> stop() => player.stop();

  Future<void> dispose() async {
    await player.dispose();
  }
}
