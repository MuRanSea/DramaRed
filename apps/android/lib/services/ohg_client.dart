import 'dart:async';
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

  /// Discover with timeout + search fallback (mirrors desktop daemon empty-page handling).
  /// Soft emulators often hit OHG empty/timeout; search is usually still available.
  Future<PagedResult<SeriesSummary>> discoverResilient({
    Duration timeout = const Duration(seconds: 35),
  }) async {
    Object? lastErr;
    try {
      final page = await discover().timeout(timeout);
      if (page.items.isNotEmpty) return page;
    } catch (e) {
      lastErr = e;
    }

    const fallbacks = <String>['短剧', '总裁', '重生', '逆袭'];
    for (final q in fallbacks) {
      try {
        final page = await search(q).timeout(timeout);
        if (page.items.isNotEmpty) return page;
      } catch (e) {
        lastErr = e;
      }
    }

    if (lastErr != null) {
      throw lastErr;
    }
    return PagedResult<SeriesSummary>(items: const []);
  }

  Future<PagedResult<SeriesSummary>> search(String query) async {
    final page = await _native.search(query);
    return _enrichSearchCovers(page);
  }

  /// openhongguo search often omits cover_url on the series_title path;
  /// fill from getSeriesBatch like the desktop daemon.
  Future<PagedResult<SeriesSummary>> _enrichSearchCovers(
    PagedResult<SeriesSummary> page,
  ) async {
    final need = <String>[];
    for (final it in page.items) {
      if (it.coverUrl.isEmpty && it.id.isNotEmpty) {
        need.add(it.id);
      }
    }
    if (need.isEmpty) return page;
    final ids = need.length > 12 ? need.sublist(0, 12) : need;
    try {
      final details = await _native.getSeriesBatch(ids).timeout(
        const Duration(seconds: 25),
      );
      final byId = <String, SeriesSummary>{};
      for (final d in details) {
        final s = d.series;
        if (s == null) continue;
        if (s.coverUrl.isEmpty) continue;
        byId[s.id] = SeriesSummary(
          id: s.id,
          title: s.title,
          description: s.description,
          coverUrl: s.coverUrl,
          episodeCount: s.episodeCount,
        );
      }
      if (byId.isEmpty) return page;
      final items = page.items.map((it) {
        if (it.coverUrl.isNotEmpty) return it;
        final fill = byId[it.id];
        if (fill == null) return it;
        return SeriesSummary(
          id: it.id,
          title: it.title,
          description: it.description.isNotEmpty ? it.description : fill.description,
          coverUrl: fill.coverUrl,
          episodeCount: it.episodeCount != 0 ? it.episodeCount : fill.episodeCount,
        );
      }).toList();
      return PagedResult<SeriesSummary>(
        items: items,
        cursor: page.cursor,
        hasMore: page.hasMore,
      );
    } catch (_) {
      return page;
    }
  }

  Future<PagedResult<Episode>> listEpisodes(String seriesId) =>
      _native.listEpisodes(seriesId);

  Future<PlaybackResult> resolvePlayback(String episodeId) =>
      _native.resolvePlayback(episodeId);

  Future<void> release() async {
    await _native.release();
    _instance = null;
  }
}
