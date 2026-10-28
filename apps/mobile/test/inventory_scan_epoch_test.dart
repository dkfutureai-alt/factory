import 'package:flutter_test/flutter_test.dart';
import 'package:factoryos_mobile/inventory_scan_epoch.dart';

void main() {
  group('InventoryScanEpoch', () {
    test('accepts current workspace response', () {
      final session = InventoryScanEpoch('org-a');
      final token = session.start('org-a');
      expect(session.accepts('org-a', token), isTrue);
      expect(session.accepts('org-b', token), isFalse);
    });

    test('invalidates old results on organization switch', () {
      final session = InventoryScanEpoch('org-a');
      final previous = session.start('org-a');
      session.selectOrganization('org-b');

      expect(session.accepts('org-a', previous), isFalse);
      final next = session.start('org-b');
      expect(session.accepts('org-b', next), isTrue);
      expect(session.accepts('org-a', previous), isFalse);
    });

    test('switching back does not revive an old result', () {
      final session = InventoryScanEpoch('org-a');
      final old = session.start('org-a');
      session.selectOrganization('org-b');
      session.selectOrganization('org-a');
      expect(session.accepts('org-a', old), isFalse);
    });

    test('later scan invalidates older response in same organization', () {
      final session = InventoryScanEpoch('org-a');
      final first = session.start('org-a');
      final second = session.start('org-a');
      expect(session.accepts('org-a', first), isFalse);
      expect(session.accepts('org-a', second), isTrue);
    });

    test('same organization reselect does not reject its in-flight result', () {
      final session = InventoryScanEpoch('org-a');
      final token = session.start('org-a');
      session.selectOrganization('org-a');
      expect(session.accepts('org-a', token), isTrue);
    });

    test('cannot start request for a different organization', () {
      final session = InventoryScanEpoch('org-a');
      expect(() => session.start('org-b'), throwsStateError);
    });

    test('explicit invalidation rejects in-flight response', () {
      final session = InventoryScanEpoch('org-a');
      final token = session.start('org-a');
      session.invalidate();
      expect(session.accepts('org-a', token), isFalse);
    });
  });
}
