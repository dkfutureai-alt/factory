import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'data/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.repository = const PreviewAuthRepository(),
    this.connectionLabel = 'Preview mode',
  });

  final AuthRepository repository;
  final String connectionLabel;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _signingIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false) || _signingIn) return;
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.signIn(email: _email.text, password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/admin');
    } on FactoryOsAuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to sign in. Check the backend connection and try again.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.repository.isLive;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.brand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('FO', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Welcome to FactoryOS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.text)),
                  const SizedBox(height: 8),
                  const Text('Sign in to continue to your factory workspace.', style: TextStyle(color: AppTheme.muted, height: 1.5)),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: live ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: live ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(live ? Icons.cloud_done_outlined : Icons.science_outlined, size: 16, color: live ? AppTheme.success : AppTheme.muted),
                          const SizedBox(width: 8),
                          Text(widget.connectionLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: live ? AppTheme.success : AppTheme.muted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_signingIn,
                          decoration: const InputDecoration(labelText: 'Email address'),
                          validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          enabled: !_signingIn,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: _signingIn ? null : () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                          onFieldSubmitted: (_) => _signIn(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _signingIn ? null : () {}, child: const Text('Forgot password?')),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _signingIn ? null : _signIn,
                          child: _signingIn
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    live
                        ? 'Live backend mode. Access is enforced by Supabase Auth and FactoryOS RLS policies.'
                        : 'Preview build. No live backend mutations are available in this mode.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
