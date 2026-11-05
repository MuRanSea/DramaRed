import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openhongguo/openhongguo.dart';

import 'player_promote_slot.dart';

/// media_kit playback helper. ClearKey / decryption_key is best-effort.
/// Optionally keeps a standby [Player] that has already opened the next episode.
class PlayerController {
  PlayerController() : _slot = PlayerPromoteSlot(Player()) {
    player = _slot.current;
  }

  late Player player;
  final PlayerPromoteSlot<Player> _slot;

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

  static bool _usable(Episode e) => e.id.isNotEmpty;

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
      if (_usable(episodes[i])) return episodes[i];
    }
    return null;
  }

  /// Previous playable episode before [currentId], or null.
  static Episode? previousEpisode(List<Episode> episodes, String currentId) {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexWhere((e) => e.id == currentId);
    if (idx <= 0) return null;
    for (var i = idx - 1; i >= 0; i--) {
      if (episodes[i].id.isNotEmpty && episodes[i].playable) {
        return episodes[i];
      }
      if (_usable(episodes[i])) return episodes[i];
    }
    return null;
  }

  static Future<void> applyContentKey(Player target, PlaybackResult result) async {
    final key = result.contentKey?.key;
    if (key == null || key.isEmpty) return;
    final platform = target.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty('demuxer-lavf-o', 'decryption_key=$key');
      } catch (_) {}
    }
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

    await applyContentKey(player, result);
    await player.open(Media(stream.url));
    if (seekTo != null && seekTo > Duration.zero) {
      // Give demuxer a beat before seek on slow emulators.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        await player.seek(seekTo);
      } catch (_) {}
    }
  }

  bool isPreloaded(String episodeId) => _slot.isPreloaded(episodeId);

  /// Open [result] on a standby player (paused) so the next swipe can promote it.
  Future<void> preloadPlayback(
    PlaybackResult result,
    String episodeId, {
    String? preferDefinition,
  }) async {
    if (episodeId.isEmpty || _slot.isPreloaded(episodeId)) return;
    final stream = pickStream(result.playback, preferDefinition: preferDefinition);
    if (stream == null) return;

    final previous = _slot.clearStandby();
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }

    final standby = Player();
    _slot.replaceStandby(standby);
    try {
      await applyContentKey(standby, result);
      await standby.open(Media(stream.url), play: false);
      if (!_slot.holds(standby)) {
        try {
          await standby.dispose();
        } catch (_) {}
        return;
      }
      _slot.markReady(standby, episodeId);
    } catch (_) {
      _slot.discardIf(standby);
      try {
        await standby.dispose();
      } catch (_) {}
    }
  }

  /// Swap the standby player in as [player]. Caller must rebuild [VideoController].
  Future<bool> takePreloaded(String episodeId) async {
    final old = _slot.take(episodeId);
    if (old == null) return false;
    player = _slot.current;
    try {
      await old.stop();
    } catch (_) {}
    try {
      await old.dispose();
    } catch (_) {}
    try {
      await player.play();
    } catch (_) {}
    debugPrint('[DramaRedPlayer] promoted episode=$episodeId');
    return true;
  }

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> pause() => player.pause();

  Future<void> play() => player.play();

  Future<void> stop() => player.stop();

  Future<void> dispose() async {
    final standby = _slot.clearStandby();
    if (standby != null) {
      try {
        await standby.dispose();
      } catch (_) {}
    }
    await player.dispose();
  }
}
