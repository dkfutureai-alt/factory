import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'factoryos_routes.dart';

void main() => runApp(const FactoryOsApp());

class FactoryOsApp extends StatelessWidget {
  const FactoryOsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FactoryOS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    initialRoute: '/',
    routes: FactoryOsRoutes.routes,
  );
}
