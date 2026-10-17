import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main_phase11.dart';

void main() {
  test('AppConfig requires both Supabase URL and publishable key', () {
    expect(const AppConfig('', '').isConfigured, isFalse);
    expect(const AppConfig('https://example.supabase.co', '').isConfigured, isFalse);
    expect(const AppConfig('', 'publishable-key').isConfigured, isFalse);
    expect(
      const AppConfig('https://example.supabase.co', 'publishable-key').isConfigured,
      isTrue,
    );
  });

  testWidgets('Admin app shows safe configuration guidance without secrets', (
    tester,
  ) async {
    await tester.pumpWidget(const FactoryAdminApp(config: AppConfig('', '')));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      find.text(
        'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using --dart-define.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('service_role'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
  });
}
