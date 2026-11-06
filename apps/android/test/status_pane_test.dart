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
}
