import 'package:dramared/services/favorites_store.dart';
import 'package:dramared/services/history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhongguo/openhongguo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('HistoryStore', () {
    test('upsert persists and resumes by series', () async {
      final store = HistoryStore();
      await store.upsert(
        HistoryEntry(
          seriesId: 's1',
          episodeId: 'e2',
          title: '剧 · 2',
          seriesTitle: '剧',
          positionMs: 12345,
          updatedAt: DateTime.utc(2026, 11, 5),
        ),
      );
      await store.upsert(
        HistoryEntry(
          seriesId: 's1',
          episodeId: 'e3',
          title: '剧 · 3',
          seriesTitle: '剧',
          positionMs: 500,
          updatedAt: DateTime.utc(2026, 11, 5, 1),
        ),
      );
      final list = await store.list();
      expect(list.length, 1);
      expect(list.first.episodeId, 'e3');
      expect(list.first.positionMs, 500);

      final got = await store.getBySeries('s1');
      expect(got?.positionMs, 500);

      await store.remove('s1');
      expect(await store.list(), isEmpty);
    });
  });

  group('FavoritesStore', () {
    test('add/remove/contains with summary metadata', () async {
      final store = FavoritesStore();
      const summary = SeriesSummary(
        id: 's9',
        title: '收藏剧',
        coverUrl: 'https://example.com/c.jpg',
        episodeCount: 40,
        category: '都市',
      );
      await store.addSummary(summary);
      expect(await store.contains('s9'), isTrue);
      final list = await store.list();
      expect(list.single.title, '收藏剧');
      expect(list.single.toSummary().episodeCount, 40);

      await store.remove('s9');
      expect(await store.contains('s9'), isFalse);
    });

    test('migrates legacy string-list favorites', () async {
      SharedPreferences.setMockInitialValues({
        'dramared.favorites': <String>['legacy-a', 'legacy-b'],
      });
      final store = FavoritesStore();
      final list = await store.list();
      expect(list.map((e) => e.seriesId).toList(), ['legacy-a', 'legacy-b']);
      // Second read uses v2 key.
      final again = await store.list();
      expect(again.length, 2);
    });
  });
}
