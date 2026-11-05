import 'package:flutter/widgets.dart';

/// How [_load] should obtain and open the next episode.
enum PlaybackLoadKind {
  /// Swap in a standby player that already opened this episode.
  promote,

  /// Re-open a cached [PlaybackResult] on the active player.
  useCache,

  /// Call OHG [resolvePlayback] and open the result.
  resolve,
}

/// Pure playback decisions shared by [PlayerPage] and tests.
class PlaybackPolicies {
  static const swipeVelocityThreshold = 400.0;

  /// 1 = next (swipe up), -1 = previous (swipe down), 0 = ignore.
  static int swipeDirection(
    double primaryVelocity, {
    double threshold = swipeVelocityThreshold,
  }) {
    if (primaryVelocity < -threshold) return 1;
    if (primaryVelocity > threshold) return -1;
    return 0;
  }

  static PlaybackLoadKind decideLoad({
    required bool forceResolve,
    required bool preloaded,
    required bool cached,
  }) {
    if (forceResolve) return PlaybackLoadKind.resolve;
    if (preloaded) return PlaybackLoadKind.promote;
    if (cached) return PlaybackLoadKind.useCache;
    return PlaybackLoadKind.resolve;
  }

  /// When background listen is off, pause as the app leaves the foreground.
  static bool shouldPauseOnBackground({
    required bool backgroundListen,
    required AppLifecycleState state,
  }) {
    if (backgroundListen) return false;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
  }

  static DateTime? stopDeadline(DateTime now, int minutes) {
    if (minutes <= 0) return null;
    return now.add(Duration(minutes: minutes));
  }

  static bool shouldFireStop(DateTime now, DateTime? deadline) {
    if (deadline == null) return false;
    return !now.isBefore(deadline);
  }
}
