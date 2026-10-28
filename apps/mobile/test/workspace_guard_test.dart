import 'package:factoryos_mobile/workspace_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single active membership preserves the exact chosen organization', () {
    final item = <String, dynamic>{
      'organization_id': '00000000-0000-4000-8000-000000000001',
      'role': 'employee',
    };
    final selected = requireSingleActiveMembership([item]);
    expect(selected['organization_id'], item['organization_id']);
    expect(selected['role'], 'employee');
  });

  test('no memberships cannot silently authorize a workspace', () {
    expect(() => requireSingleActiveMembership([]), throwsStateError);
  });

  test('multiple memberships must not silently pick first or last', () {
    final a = <String, dynamic>{'organization_id': 'tenant-a'};
    final b = <String, dynamic>{'organization_id': 'tenant-b'};
    for (final memberships in [[a, b], [b, a]]) {
      expect(
        () => requireSingleActiveMembership(memberships),
        throwsA(isA<StateError>().having(
          (e) => e.message.toString(),
          'explanation',
          contains('multiple active organizations'),
        )),
      );
    }
  });

  test('guard does not use user-provided role or organization to bypass count', () {
    expect(
      () => requireSingleActiveMembership([
        {'organization_id': 'tenant-a', 'role': 'org_admin'},
        {'organization_id': 'tenant-b', 'role': 'employee'},
      ]),
      throwsStateError,
    );
  });
}
