import 'package:factoryos_mobile/push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase release configuration stays disabled without dart defines', () {
    final config = FirebaseRuntimeConfig.fromEnvironment();

    expect(config.hasAnyValue, isFalse);
    expect(config.isConfigured, isFalse);
  });
}
