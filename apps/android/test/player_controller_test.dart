import 'package:dramared/services/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhongguo/openhongguo.dart';

VideoStream _stream({
  required String def,
  required int height,
  String url = 'https://example.com/v.mp4',
}) {
  return VideoStream(
    definition: def,
    quality: def,
    height: height,
    width: height * 9 ~/ 16,
    url: url,
  );
}

void main() {
  group('pickStream', () {
    test('prefers matching definition', () {
      final pb = Playback(
        streams: [
          _stream(def: '360p', height: 360),
          _stream(def: '720p', height: 720),
        ],
      );
      final s = PlayerController.pickStream(pb, preferDefinition: '720p');
      expect(s?.definition, '720p');
    });

    test('自动 picks highest height', () {
      final pb = Playback(
        streams: [
          _stream(def: '360p', height: 360),
          _stream(def: '1080p', height: 1080),
          _stream(def: '720p', height: 720),
        ],
      );
      final s = PlayerController.pickStream(pb, preferDefinition: '自动');
      expect(s?.height, 1080);
    });

    test('empty streams → null', () {
      expect(PlayerController.pickStream(const Playback()), isNull);
    });
  });

  group('nextEpisode', () {
    test('returns next playable', () {
      final eps = [
        const Episode(id: 'a', number: 1, playable: true),
        const Episode(id: 'b', number: 2, playable: true),
        const Episode(id: 'c', number: 3, playable: true),
      ];
      expect(PlayerController.nextEpisode(eps, 'a')?.id, 'b');
      expect(PlayerController.nextEpisode(eps, 'c'), isNull);
    });

    test('unknown current → null', () {
      expect(
        PlayerController.nextEpisode(
          const [Episode(id: 'a', playable: true)],
          'x',
        ),
        isNull,
      );
    });
  });
}
