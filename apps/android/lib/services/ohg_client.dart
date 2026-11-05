// openhongguo 封装占位。真实调用需在 Android/iOS 设备或模拟器上，
// 且已 flutter pub get 拉取 openhongguo 0.2.0 原生库。
//
// import 'package:openhongguo/openhongguo.dart';

/// 对 OpenhongguoClient 的薄封装，便于测试替换。
class OhgClient {
  OhgClient._();

  static OhgClient? _instance;

  static Future<OhgClient> create() async {
    // TODO: final native = await OpenhongguoClient.create();
    return _instance ??= OhgClient._();
  }

  Future<void> discover() async {
    // TODO: native.discover(...)
    throw UnimplementedError('OhgClient.discover');
  }

  Future<void> search(String query) async {
    // TODO: native.search(query)
    throw UnimplementedError('OhgClient.search');
  }

  Future<void> listEpisodes(String seriesId) async {
    // TODO: native.listEpisodes(seriesId)
    throw UnimplementedError('OhgClient.listEpisodes');
  }

  Future<void> resolvePlayback(String episodeId) async {
    // TODO: native.resolvePlayback(episodeId)
    throw UnimplementedError('OhgClient.resolvePlayback');
  }

  Future<void> release() async {
    // TODO: native.release()
  }
}
