import 'package:factoryos_mobile/scoped_push_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const organizationA = '00000000-0000-4000-8000-000000000001';
  const organizationB = '00000000-0000-4000-8000-000000000002';
  const userA = '00000000-0000-4000-8000-000000000003';
  const userB = '00000000-0000-4000-8000-000000000004';

  ScopedPushRoute route({
    String organizationId = organizationA,
    String userId = userA,
    String actionRoute = 'inventory',
  }) {
    return ScopedPushRoute(
      organizationId: organizationId,
      recipientUserId: userId,
      actionRoute: actionRoute,
    );
  }

  test('FCM route requires a populated tenant, recipient and action route', () {
    expect(ScopedPushRoute.fromData(<String, dynamic>{
      'organization_id': organizationA,
      'recipient_user_id': userA,
      'action_route': 'inventory',
    })?.actionRoute, 'inventory');
    for (final field in <String>[
      'organization_id',
      'recipient_user_id',
      'action_route',
    ]) {
      final data = <String, dynamic>{
        'organization_id': organizationA,
        'recipient_user_id': userA,
        'action_route': 'inventory',
      }..remove(field);
      expect(ScopedPushRoute.fromData(data), isNull,
          reason: 'Missing $field must fail closed');
      data[field] = '   ';
      expect(ScopedPushRoute.fromData(data), isNull,
          reason: 'Empty $field must fail closed');
    }
  });

  test('legacy unscoped route cannot be opened', () {
    expect(ScopedPushRoute.fromData(const <String, dynamic>{
      'action_route': 'inventory',
    }), isNull);
  });

  test('malformed payload types cannot be used for navigation', () {
    expect(ScopedPushRoute.fromData(const <String, dynamic>{
      'organization_id': 42,
      'recipient_user_id': true,
      'action_route': ['inventory'],
    }), isNull);
  });

  test('cross-tenant and cross-user messages never match active workspace', () {
    final forA = route();
    expect(forA.matches(
      organizationId: organizationA,
      recipientUserId: userA,
    ), isTrue);
    expect(forA.matches(
      organizationId: organizationB,
      recipientUserId: userA,
    ), isFalse);
    expect(forA.matches(
      organizationId: organizationA,
      recipientUserId: userB,
    ), isFalse);
  });

  test('pending cold-start push opens only in exact signed-in workspace', () {
    final mailbox = ScopedPushMailbox()..store(route());
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userA,
    ), 'inventory');
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userA,
    ), isNull);
  });

  test('pending push for another organization is discarded, not deferred', () {
    final mailbox = ScopedPushMailbox()..store(route());
    expect(mailbox.consumeFor(
      organizationId: organizationB,
      recipientUserId: userA,
    ), isNull);
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userA,
    ), isNull);
  });

  test('shared device changing users cannot reopen previous user push', () {
    final mailbox = ScopedPushMailbox()..store(route());
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userB,
    ), isNull);
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userA,
    ), isNull);
  });

  test('sign out explicitly clears pending push routing', () {
    final mailbox = ScopedPushMailbox()
      ..store(route(actionRoute: 'delivery'))
      ..clear();
    expect(mailbox.consumeFor(
      organizationId: organizationA,
      recipientUserId: userA,
    ), isNull);
  });
}
