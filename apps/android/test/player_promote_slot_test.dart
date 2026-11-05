import 'package:dramared/services/player_promote_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerPromoteSlot', () {
    test('promote swaps standby in and returns the retired current', () {
      final slot = PlayerPromoteSlot<String>('active-ep1');
      expect(slot.isPreloaded('ep2'), isFalse);

      expect(slot.replaceStandby('standby-ep2'), isNull);
      expect(slot.isPreloaded('ep2'), isFalse);

      slot.markReady('standby-ep2', 'ep2');
      expect(slot.isPreloaded('ep2'), isTrue);
      expect(slot.isPreloaded('ep3'), isFalse);

      final retired = slot.take('ep2');
      expect(retired, 'active-ep1');
      expect(slot.current, 'standby-ep2');
      expect(slot.isPreloaded('ep2'), isFalse);
      expect(slot.take('ep2'), isNull);
    });

    test('take rejects a mismatched episode and leaves standby intact', () {
      final slot = PlayerPromoteSlot<String>('a');
      slot.replaceStandby('b');
      slot.markReady('b', 'ep2');
      expect(slot.take('ep3'), isNull);
      expect(slot.current, 'a');
      expect(slot.isPreloaded('ep2'), isTrue);
    });

    test('replaceStandby returns the previous unused standby', () {
      final slot = PlayerPromoteSlot<String>('a');
      slot.replaceStandby('first');
      slot.markReady('first', 'ep2');
      final evicted = slot.replaceStandby('second');
      expect(evicted, 'first');
      expect(slot.isPreloaded('ep2'), isFalse);
      slot.markReady('second', 'ep3');
      expect(slot.isPreloaded('ep3'), isTrue);
    });

    test('discardIf drops a cancelled open without touching current', () {
      final slot = PlayerPromoteSlot<String>('a');
      slot.replaceStandby('pending');
      slot.discardIf('pending');
      expect(slot.standby, isNull);
      expect(slot.current, 'a');
      expect(slot.take('ep2'), isNull);
    });

    test('clearStandby forgets a staged player', () {
      final slot = PlayerPromoteSlot<String>('a');
      slot.replaceStandby('pending');
      slot.markReady('pending', 'ep2');
      expect(slot.clearStandby(), 'pending');
      expect(slot.isPreloaded('ep2'), isFalse);
    });

    test('markReady ignores a player that is no longer standby', () {
      final slot = PlayerPromoteSlot<String>('a');
      slot.replaceStandby('pending');
      slot.replaceStandby('newer');
      slot.markReady('pending', 'ep2');
      expect(slot.isPreloaded('ep2'), isFalse);
      slot.markReady('newer', 'ep3');
      expect(slot.isPreloaded('ep3'), isTrue);
    });
  });
}
