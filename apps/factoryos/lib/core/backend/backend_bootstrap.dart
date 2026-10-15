import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';
import 'factoryos_services.dart';

class FactoryOsBackendBootstrapFailure implements Exception {
  const FactoryOsBackendBootstrapFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<FactoryOsServices> bootstrapFactoryOsServices(
  FactoryOsBackendConfig config,
) async {
  if (config.isPreview) return FactoryOsServices.preview(config);

  final errors = config.validationErrors;
  if (errors.isNotEmpty) {
    throw FactoryOsBackendBootstrapFailure(errors.join(' '));
  }

  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    debug: false,
  );

  return FactoryOsServices.supabase(
    config: config,
    client: Supabase.instance.client,
  );
}
