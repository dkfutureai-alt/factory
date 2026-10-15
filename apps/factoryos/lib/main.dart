import 'package:flutter/material.dart';

import 'core/backend/backend_bootstrap.dart';
import 'core/backend/backend_config.dart';
import 'core/theme/app_theme.dart';
import 'factoryos_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = FactoryOsBackendConfig.fromEnvironment();

  try {
    final services = await bootstrapFactoryOsServices(config);
    runApp(
      FactoryOsApp(
        routes: FactoryOsRoutes.forServices(services),
        initialRoute: services.authRepository.currentSession() == null ? '/' : '/admin',
      ),
    );
  } on FactoryOsBackendBootstrapFailure catch (error) {
    runApp(FactoryOsConfigurationErrorApp(message: error.message));
  }
}

class FactoryOsApp extends StatelessWidget {
  const FactoryOsApp({
    super.key,
    this.routes,
    this.initialRoute = '/',
  });

  final Map<String, WidgetBuilder>? routes;
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FactoryOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: initialRoute,
        routes: routes ?? FactoryOsRoutes.routes,
      );
}

class FactoryOsConfigurationErrorApp extends StatelessWidget {
  const FactoryOsConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FactoryOS configuration',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42, color: AppTheme.danger),
                        const SizedBox(height: 16),
                        const Text('FactoryOS backend configuration is incomplete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(message, style: const TextStyle(color: AppTheme.muted, height: 1.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No fallback to demo data is performed when Supabase mode is requested. Fix the FactoryOS environment configuration and restart the app.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
