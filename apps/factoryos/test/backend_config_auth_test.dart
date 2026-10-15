import 'package:factoryos/core/backend/backend_config.dart';
import 'package:factoryos/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview backend is valid without Supabase credentials', () {
    const config = FactoryOsBackendConfig(mode: FactoryOsBackendMode.preview);
    expect(config.isValid, isTrue);
    expect(config.connectionLabel, 'Preview mode');
  });

  test('Supabase backend requires URL and publishable key', () {
    const missing = FactoryOsBackendConfig(mode: FactoryOsBackendMode.supabase);
    expect(missing.isValid, isFalse);
    expect(missing.validationErrors, hasLength(2));

    const valid = FactoryOsBackendConfig(
      mode: FactoryOsBackendMode.supabase,
      supabaseUrl: 'https://factoryos.example.supabase.co',
      supabasePublishableKey: 'sb_publishable_factoryos_test',
    );
    expect(valid.isValid, isTrue);
    expect(valid.connectionLabel, 'Backend connected');
  });

  test('non-local Supabase URL must use HTTPS', () {
    const config = FactoryOsBackendConfig(
      mode: FactoryOsBackendMode.supabase,
      supabaseUrl: 'http://factoryos.example.supabase.co',
      supabasePublishableKey: 'sb_publishable_factoryos_test',
    );
    expect(config.isValid, isFalse);
    expect(config.validationErrors.single, contains('HTTPS'));
  });

  test('preview Auth returns explicitly preview session', () async {
    const repository = PreviewAuthRepository();
    final session = await repository.signIn(email: 'Manager@Example.Test', password: 'preview123');
    expect(repository.isLive, isFalse);
    expect(session.email, 'manager@example.test');
    expect(session.isPreview, isTrue);
    expect(session.userId, 'preview-user');
  });

  test('preview Auth rejects invalid credentials shape', () async {
    const repository = PreviewAuthRepository();
    expect(
      () => repository.signIn(email: 'invalid', password: '123'),
      throwsA(isA<FactoryOsAuthFailure>()),
    );
  });
}
