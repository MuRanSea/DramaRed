import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const _key = 'dramared.favorites';

  Future<List<String>> listSeriesIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String seriesId) async {
    final ids = await listSeriesIds();
    if (ids.contains(seriesId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [...ids, seriesId]);
  }

  Future<void> remove(String seriesId) async {
    final ids = await listSeriesIds();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      ids.where((id) => id != seriesId).toList(),
    );
  }

  Future<bool> contains(String seriesId) async {
    final ids = await listSeriesIds();
    return ids.contains(seriesId);
  }
}
