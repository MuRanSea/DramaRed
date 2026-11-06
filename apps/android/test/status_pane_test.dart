import 'package:dramared/widgets/status_pane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friendlyError maps network and gateway phrases', () {
    expect(StatusPane.friendlyError(Exception('SocketException: failed host')), contains('网络'));
    expect(StatusPane.friendlyError('timeout while waiting'), contains('超时'));
    expect(StatusPane.friendlyError('502 Bad Gateway'), contains('繁忙'));
    expect(StatusPane.friendlyError('anonymous response was empty'), contains('推荐'));
  });

  test('friendlyError truncates long technical dumps', () {
    final long = 'x' * 200;
    final out = StatusPane.friendlyError(long);
    expect(out.length, lessThanOrEqualTo(100));
    expect(out.endsWith('…'), isTrue);
  });

  test('friendlyError and friendlyPlaybackStatus scrub ClearKey / DRM jargon', () {
    expect(
      StatusPane.friendlyError('受保护流 (尝试 ClearKey/decryption_key)'),
      StatusPane.playFailedFriendly,
    );
    expect(
      StatusPane.friendlyError('demuxer failed decryption_key missing'),
      StatusPane.playFailedFriendly,
    );
    expect(
      StatusPane.friendlyPlaybackStatus('此集受保护，暂无法解密'),
      StatusPane.playFailedFriendly,
    );
    expect(
      StatusPane.friendlyPlaybackStatus('播放失败：ClearKey setup'),
      StatusPane.playFailedFriendly,
    );
    expect(StatusPane.friendlyPlaybackStatus('缓冲中…'), '缓冲中…');
  });

}
