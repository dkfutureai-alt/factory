import 'package:flutter_test/flutter_test.dart';
import 'package:factoryos_mobile/inventory_scan_epoch.dart';

void main() {
  group('InventoryScanEpoch', () {
    test('accepts current authenticated workspace response', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final token = session.start('org-a', 'user-a');
      expect(session.accepts('org-a', 'user-a', token), isTrue);
      expect(session.accepts('org-b', 'user-a', token), isFalse);
      expect(session.accepts('org-a', 'user-b', token), isFalse);
    });

    test('invalidates old results on organization switch', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final previous = session.start('org-a', 'user-a');
      expect(session.selectWorkspace('org-b', 'user-a'), isTrue);
      expect(session.accepts('org-a', 'user-a', previous), isFalse);
      final next = session.start('org-b', 'user-a');
      expect(session.accepts('org-b', 'user-a', next), isTrue);
    });

    test('switching back never revives a previous tenant request', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final old = session.start('org-a', 'user-a');
      session.selectWorkspace('org-b', 'user-a');
      session.selectWorkspace('org-a', 'user-a');
      expect(session.accepts('org-a', 'user-a', old), isFalse);
    });

    test('different user in same organization discards an in-flight scan', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final old = session.start('org-a', 'user-a');
      expect(session.selectWorkspace('org-a', 'user-b'), isTrue);
      expect(session.accepts('org-a', 'user-a', old), isFalse);
      expect(session.accepts('org-a', 'user-b', old), isFalse);
      final next = session.start('org-a', 'user-b');
      expect(session.accepts('org-a', 'user-b', next), isTrue);
    });

    test('sign out clears pending results and blocks anonymous scans', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final old = session.start('org-a', 'user-a');
      session.selectWorkspace('org-a', null);
      expect(session.accepts('org-a', null, old), isFalse);
      expect(() => session.start('org-a', null), throwsStateError);
      session.selectWorkspace('org-a', 'user-a');
      expect(session.accepts('org-a', 'user-a', old), isFalse);
    });

    test('later scan invalidates older response in same authenticated workspace', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final first = session.start('org-a', 'user-a');
      final second = session.start('org-a', 'user-a');
      expect(session.accepts('org-a', 'user-a', first), isFalse);
      expect(session.accepts('org-a', 'user-a', second), isTrue);
    });

    test('same workspace reselect preserves the in-flight request', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final token = session.start('org-a', 'user-a');
      expect(session.selectWorkspace('org-a', 'user-a'), isFalse);
      expect(session.accepts('org-a', 'user-a', token), isTrue);
    });

    test('cannot start requests for another user or organization', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      expect(() => session.start('org-b', 'user-a'), throwsStateError);
      expect(() => session.start('org-a', 'user-b'), throwsStateError);
      expect(() => session.start('org-a', ''), throwsStateError);
    });

    test('no unauthenticated or unstarted result can be accepted', () {
      final session = InventoryScanEpoch('org-a', null);
      expect(session.accepts('org-a', null, 0), isFalse);
      expect(() => session.start('org-a', null), throwsStateError);
    });

    test('explicit invalidation rejects in-flight responses', () {
      final session = InventoryScanEpoch('org-a', 'user-a');
      final token = session.start('org-a', 'user-a');
      session.invalidate();
      expect(session.accepts('org-a', 'user-a', token), isFalse);
    });
  });
}
