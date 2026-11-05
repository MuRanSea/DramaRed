import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  HistoryEntry({
    required this.seriesId,
    required this.episodeId,
    required this.title,
    required this.positionMs,
    required this.updatedAt,
    this.seriesTitle = '',
    this.coverUrl = '',
    this.episodeNumber = 0,
    this.episodeCount = 0,
  });

  final String seriesId;
  final String episodeId;
  final String title;
  final String seriesTitle;
  final String coverUrl;
  final int episodeNumber;
  final int episodeCount;
  final int positionMs;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'seriesId': seriesId,
        'episodeId': episodeId,
        'title': title,
        'seriesTitle': seriesTitle,
        'coverUrl': coverUrl,
        'episodeNumber': episodeNumber,
        'episodeCount': episodeCount,
        'positionMs': positionMs,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        seriesId: j['seriesId'] as String? ?? '',
        episodeId: j['episodeId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        seriesTitle: j['seriesTitle'] as String? ?? '',
        coverUrl: j['coverUrl'] as String? ?? '',
        episodeNumber: j['episodeNumber'] as int? ?? 0,
        episodeCount: j['episodeCount'] as int? ?? 0,
        positionMs: j['positionMs'] as int? ?? 0,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class HistoryStore {
  static const _key = 'dramared.history';

  Future<List<HistoryEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<HistoryEntry?> getBySeries(String seriesId) async {
    final items = await list();
    for (final e in items) {
      if (e.seriesId == seriesId) return e;
    }
    return null;
  }

  Future<void> upsert(HistoryEntry entry) async {
    if (entry.seriesId.isEmpty && entry.episodeId.isEmpty) return;
    final items = await list();
    final next = [
      entry,
      ...items.where((e) => e.seriesId != entry.seriesId),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String seriesId) async {
    final items = await list();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(
        items.where((e) => e.seriesId != seriesId).map((e) => e.toJson()).toList(),
      ),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
