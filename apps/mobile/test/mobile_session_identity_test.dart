import 'package:factoryos_mobile/mobile_session_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileAccountChangeTracker', () {
    test('same user token refresh does not dismiss their active work', () {
      final tracker = MobileAccountChangeTracker('user-a');
      expect(tracker.changedTo('user-a'), isFalse);
      expect(tracker.changedTo('user-a'), isFalse);
    });

    test('sign-out resets navigation once', () {
      final tracker = MobileAccountChangeTracker('user-a');
      expect(tracker.changedTo(null), isTrue);
      expect(tracker.changedTo(null), isFalse);
    });

    test('shared-device user switch always resets navigation', () {
      final tracker = MobileAccountChangeTracker('user-a');
      expect(tracker.changedTo('user-b'), isTrue);
      expect(tracker.changedTo('user-a'), isTrue);
    });

    test('first sign-in from a signed-out app resets prior routes', () {
      final tracker = MobileAccountChangeTracker(null);
      expect(tracker.changedTo('user-a'), isTrue);
      expect(tracker.changedTo('user-a'), isFalse);
    });
  });

  group('MobileSessionIdentity', () {
    const owner = 'user-a';
    const other = 'user-b';

    test('only the same authenticated user can receive the workspace', () {
      const identity = MobileSessionIdentity(owner);
      expect(identity.matches(owner), isTrue);
      expect(identity.matches(other), isFalse);
      expect(identity.matches(null), isFalse);
      expect(identity.matches(''), isFalse);
    });

    test('same organization with another user is still a session change', () {
      // Tenant-only bootstrap checks are not enough for shared handsets.
      const previous = MobileSessionIdentity(owner);
      expect(previous.matches(other), isFalse);
      expect(() => previous.requireCurrent(other), throwsStateError);
    });

    test('sign-out prevents an in-flight workspace response from being used', () {
      const previous = MobileSessionIdentity(owner);
      expect(() => previous.requireCurrent(null), throwsStateError);
    });

    test('sign-in to the same user remains valid', () {
      const identity = MobileSessionIdentity(owner);
      expect(() => identity.requireCurrent(owner), returnsNormally);
    });

    test('blank identity cannot authorize even a blank current user', () {
      const identity = MobileSessionIdentity('');
      expect(identity.matches(''), isFalse);
      expect(() => identity.requireCurrent(''), throwsStateError);
    });

    test('a previous user result remains blocked after switching back', () {
      const previous = MobileSessionIdentity(owner);
      const replacement = MobileSessionIdentity(other);
      expect(previous.matches(other), isFalse);
      expect(replacement.matches(other), isTrue);
      expect(replacement.matches(owner), isFalse);
    });
  });
}
