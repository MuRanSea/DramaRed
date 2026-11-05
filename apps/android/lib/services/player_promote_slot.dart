/// Standby-player slot that can be promoted into [current].
///
/// Isolated from media_kit so promote/preload races can be unit-tested.
class PlayerPromoteSlot<T> {
  PlayerPromoteSlot(this.current);

  T current;
  T? standby;
  String? standbyEpisodeId;

  bool isPreloaded(String episodeId) =>
      episodeId.isNotEmpty &&
      standbyEpisodeId == episodeId &&
      standby != null;

  bool holds(T candidate) => identical(standby, candidate);

  /// Drop the current standby (not yet promoted). Returns it for disposal.
  T? clearStandby() {
    final previous = standby;
    standby = null;
    standbyEpisodeId = null;
    return previous;
  }

  /// Place [next] as standby without marking it ready.
  /// Returns the previous standby so the caller can dispose it.
  T? replaceStandby(T next) {
    final previous = standby;
    standby = next;
    standbyEpisodeId = null;
    return previous;
  }

  void markReady(T candidate, String episodeId) {
    if (identical(standby, candidate) && episodeId.isNotEmpty) {
      standbyEpisodeId = episodeId;
    }
  }

  void discardIf(T candidate) {
    if (identical(standby, candidate)) {
      standby = null;
      standbyEpisodeId = null;
    }
  }

  /// Promote matching standby into [current]. Returns the retired player,
  /// or null if nothing was ready for [episodeId].
  T? take(String episodeId) {
    final next = standby;
    if (next == null || standbyEpisodeId != episodeId) return null;
    final old = current;
    current = next;
    standby = null;
    standbyEpisodeId = null;
    return old;
  }
}
