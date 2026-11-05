import 'dart:convert';

import 'package:openhongguo/openhongguo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted favorite with enough metadata to open [SeriesPage] offline-ish.
class FavoriteEntry {
  FavoriteEntry({
    required this.seriesId,
    required this.title,
    this.coverUrl = '',
    this.description = '',
    this.episodeCount = 0,
    this.author = '',
    this.category = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String seriesId;
  final String title;
  final String coverUrl;
  final String description;
  final int episodeCount;
  final String author;
  final String category;
  final DateTime updatedAt;

  SeriesSummary toSummary() => SeriesSummary(
        id: seriesId,
        title: title,
        coverUrl: coverUrl,
        description: description,
        episodeCount: episodeCount,
        author: author,
        category: category,
      );

  factory FavoriteEntry.fromSummary(SeriesSummary s) => FavoriteEntry(
        seriesId: s.id,
        title: s.title,
        coverUrl: s.coverUrl,
        description: s.description,
        episodeCount: s.episodeCount,
        author: s.author,
        category: s.category,
      );

  Map<String, Object?> toJson() => {
        'seriesId': seriesId,
        'title': title,
        'coverUrl': coverUrl,
        'description': description,
        'episodeCount': episodeCount,
        'author': author,
        'category': category,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FavoriteEntry.fromJson(Map<String, dynamic> j) => FavoriteEntry(
        seriesId: j['seriesId'] as String? ?? j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        coverUrl: j['coverUrl'] as String? ?? '',
        description: j['description'] as String? ?? '',
        episodeCount: j['episodeCount'] as int? ?? 0,
        author: j['author'] as String? ?? '',
        category: j['category'] as String? ?? '',
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class FavoritesStore {
  static const _key = 'dramared.favorites.v2';
  static const _legacyKey = 'dramared.favorites';

  Future<List<FavoriteEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FavoriteEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.seriesId.isNotEmpty)
          .toList();
    }
    // Migrate legacy id-only list once.
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy == null || legacy.isEmpty) return const [];
    final migrated = legacy
        .where((id) => id.isNotEmpty)
        .map((id) => FavoriteEntry(seriesId: id, title: id))
        .toList();
    await _save(migrated);
    await prefs.remove(_legacyKey);
    return migrated;
  }

  Future<List<String>> listSeriesIds() async {
    final items = await list();
    return items.map((e) => e.seriesId).toList();
  }

  Future<void> _save(List<FavoriteEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(FavoriteEntry entry) async {
    if (entry.seriesId.isEmpty) return;
    final items = await list();
    final next = [
      entry,
      ...items.where((e) => e.seriesId != entry.seriesId),
    ];
    await _save(next);
  }

  Future<void> addSummary(SeriesSummary series) =>
      add(FavoriteEntry.fromSummary(series));

  Future<void> remove(String seriesId) async {
    final items = await list();
    await _save(items.where((e) => e.seriesId != seriesId).toList());
  }

  Future<bool> contains(String seriesId) async {
    final items = await list();
    return items.any((e) => e.seriesId == seriesId);
  }
}
