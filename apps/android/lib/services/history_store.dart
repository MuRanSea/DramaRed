/// 播放历史 / 续播进度本地存储占位。
class HistoryStore {
  Future<List<Map<String, Object?>>> list() async => const [];

  Future<void> upsert({
    required String seriesId,
    required String episodeId,
    required Duration position,
  }) async {
    // TODO: SharedPreferences / 文件
  }

  Future<void> remove(String seriesId) async {}
}
