import 'package:openhongguo/openhongguo.dart';

/// Thin wrapper around [OpenhongguoClient] (locked openhongguo 0.2.0).
/// Native channel only works on Android/iOS — not web/desktop.
class OhgClient {
  OhgClient._(this._native);

  final OpenhongguoClient _native;

  static OhgClient? _instance;

  static Future<OhgClient> instance() async {
    if (_instance != null) return _instance!;
    final native = await OpenhongguoClient.create();
    return _instance ??= OhgClient._(native);
  }

  Future<PagedResult<SeriesSummary>> discover() => _native.discover();

  Future<PagedResult<SeriesSummary>> search(String query) =>
      _native.search(query);

  Future<PagedResult<Episode>> listEpisodes(String seriesId) =>
      _native.listEpisodes(seriesId);

  Future<PlaybackResult> resolvePlayback(String episodeId) =>
      _native.resolvePlayback(episodeId);

  Future<void> release() async {
    await _native.release();
    _instance = null;
  }
}
