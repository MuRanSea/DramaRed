import 'package:dramared/services/playback_policies.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('swipeDirection', () {
    test('up (negative velocity) is next', () {
      expect(PlaybackPolicies.swipeDirection(-401), 1);
      expect(PlaybackPolicies.swipeDirection(-400), 0);
    });

    test('down (positive velocity) is previous', () {
      expect(PlaybackPolicies.swipeDirection(401), -1);
      expect(PlaybackPolicies.swipeDirection(400), 0);
    });

    test('weak flicks are ignored', () {
      expect(PlaybackPolicies.swipeDirection(0), 0);
      expect(PlaybackPolicies.swipeDirection(-120), 0);
    });
  });

  group('decideLoad', () {
    test('forceResolve always resolves even if preloaded or cached', () {
      expect(
        PlaybackPolicies.decideLoad(
          forceResolve: true,
          preloaded: true,
          cached: true,
        ),
        PlaybackLoadKind.resolve,
      );
    });

    test('preloaded wins over cache', () {
      expect(
        PlaybackPolicies.decideLoad(
          forceResolve: false,
          preloaded: true,
          cached: true,
        ),
        PlaybackLoadKind.promote,
      );
    });

    test('cache used when nothing is preloaded', () {
      expect(
        PlaybackPolicies.decideLoad(
          forceResolve: false,
          preloaded: false,
          cached: true,
        ),
        PlaybackLoadKind.useCache,
      );
    });

    test('fresh resolve when empty', () {
      expect(
        PlaybackPolicies.decideLoad(
          forceResolve: false,
          preloaded: false,
          cached: false,
        ),
        PlaybackLoadKind.resolve,
      );
    });
  });

  group('background listen', () {
    test('keeps playing when enabled', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.resumed,
      ]) {
        expect(
          PlaybackPolicies.shouldPauseOnBackground(
            backgroundListen: true,
            state: state,
          ),
          isFalse,
          reason: '$state should not pause when background listen is on',
        );
      }
    });

    test('pauses when disabled and leaving foreground', () {
      expect(
        PlaybackPolicies.shouldPauseOnBackground(
          backgroundListen: false,
          state: AppLifecycleState.paused,
        ),
        isTrue,
      );
      expect(
        PlaybackPolicies.shouldPauseOnBackground(
          backgroundListen: false,
          state: AppLifecycleState.inactive,
        ),
        isTrue,
      );
      expect(
        PlaybackPolicies.shouldPauseOnBackground(
          backgroundListen: false,
          state: AppLifecycleState.hidden,
        ),
        isTrue,
      );
      expect(
        PlaybackPolicies.shouldPauseOnBackground(
          backgroundListen: false,
          state: AppLifecycleState.resumed,
        ),
        isFalse,
      );
    });
  });

  group('stop-after timer', () {
    final now = DateTime.utc(2026, 11, 5, 18);

    test('0 minutes leaves the timer off', () {
      expect(PlaybackPolicies.stopDeadline(now, 0), isNull);
      expect(PlaybackPolicies.shouldFireStop(now, null), isFalse);
    });

    test('fires at and after the deadline, not before', () {
      final deadline = PlaybackPolicies.stopDeadline(now, 15)!;
      expect(deadline, DateTime.utc(2026, 11, 5, 18, 15));
      expect(
        PlaybackPolicies.shouldFireStop(
          now.add(const Duration(minutes: 14, seconds: 59)),
          deadline,
        ),
        isFalse,
      );
      expect(PlaybackPolicies.shouldFireStop(deadline, deadline), isTrue);
      expect(
        PlaybackPolicies.shouldFireStop(
          now.add(const Duration(minutes: 15, seconds: 1)),
          deadline,
        ),
        isTrue,
      );
    });
  });
}
