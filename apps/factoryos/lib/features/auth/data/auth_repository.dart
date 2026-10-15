import 'package:supabase_flutter/supabase_flutter.dart';

class FactoryOsSession {
  const FactoryOsSession({
    required this.userId,
    required this.email,
    required this.isPreview,
  });

  final String userId;
  final String email;
  final bool isPreview;
}

class FactoryOsAuthFailure implements Exception {
  const FactoryOsAuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  bool get isLive;
  Future<FactoryOsSession> signIn({required String email, required String password});
  Future<void> signOut();
  FactoryOsSession? currentSession();
}

final class PreviewAuthRepository implements AuthRepository {
  const PreviewAuthRepository();

  @override
  bool get isLive => false;

  @override
  FactoryOsSession? currentSession() => null;

  @override
  Future<FactoryOsSession> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@') || password.length < 6) {
      throw const FactoryOsAuthFailure('Enter a valid email and password.');
    }
    return FactoryOsSession(
      userId: 'preview-user',
      email: normalizedEmail,
      isPreview: true,
    );
  }

  @override
  Future<void> signOut() async {}
}

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this.client);

  final SupabaseClient client;

  @override
  bool get isLive => true;

  @override
  FactoryOsSession? currentSession() {
    final session = client.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null) return null;
    return FactoryOsSession(
      userId: user.id,
      email: user.email ?? '',
      isPreview: false,
    );
  }

  @override
  Future<FactoryOsSession> signIn({required String email, required String password}) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      final session = response.session;
      if (user == null || session == null) {
        throw const FactoryOsAuthFailure('Sign in did not return an authenticated session.');
      }
      return FactoryOsSession(
        userId: user.id,
        email: user.email ?? email.trim(),
        isPreview: false,
      );
    } on AuthException catch (error) {
      throw FactoryOsAuthFailure(error.message);
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}
