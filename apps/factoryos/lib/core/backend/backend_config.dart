enum FactoryOsBackendMode { preview, supabase }

class FactoryOsBackendConfig {
  const FactoryOsBackendConfig({
    required this.mode,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
  });

  factory FactoryOsBackendConfig.fromEnvironment() {
    const rawMode = String.fromEnvironment('FACTORYOS_BACKEND', defaultValue: 'preview');
    const url = String.fromEnvironment('FACTORYOS_SUPABASE_URL');
    const publishableKey = String.fromEnvironment('FACTORYOS_SUPABASE_PUBLISHABLE_KEY');

    return FactoryOsBackendConfig(
      mode: rawMode.trim().toLowerCase() == 'supabase'
          ? FactoryOsBackendMode.supabase
          : FactoryOsBackendMode.preview,
      supabaseUrl: url.trim(),
      supabasePublishableKey: publishableKey.trim(),
    );
  }

  final FactoryOsBackendMode mode;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isPreview => mode == FactoryOsBackendMode.preview;
  bool get isSupabase => mode == FactoryOsBackendMode.supabase;

  List<String> get validationErrors {
    if (isPreview) return const [];

    final errors = <String>[];
    final uri = Uri.tryParse(supabaseUrl);
    if (supabaseUrl.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      errors.add('FACTORYOS_SUPABASE_URL must be a valid absolute URL.');
    } else if (uri.scheme != 'https' && !_isLocalDevelopmentHost(uri.host)) {
      errors.add('FACTORYOS_SUPABASE_URL must use HTTPS outside local development.');
    }

    if (supabasePublishableKey.isEmpty) {
      errors.add('FACTORYOS_SUPABASE_PUBLISHABLE_KEY is required in Supabase mode.');
    }

    return errors;
  }

  bool get isValid => validationErrors.isEmpty;

  String get connectionLabel => isSupabase ? 'Backend connected' : 'Preview mode';

  static bool _isLocalDevelopmentHost(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  }
}
