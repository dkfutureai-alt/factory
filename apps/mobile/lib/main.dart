import 'dart:async';

import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_operations.dart';
import 'delivery_driver.dart';
import 'fleet_driver.dart';
import 'hr_self_service.dart';
import 'inventory_scanner.dart';
import 'maintenance_technician.dart';
import 'mobile_dashboard.dart';
import 'main_phase11.dart' as phase11;
import 'notification_inbox.dart';
import 'production_execution.dart';
import 'push_notifications.dart';
import 'quality_execution.dart';
import 'reports_mobile.dart';
import 'warehouse_operations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initializeFirebase();
  final config = phase11.MobileConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
    );
  }
  runApp(_FactoryMobilePhase12(config: config));
}

class _FactoryMobilePhase12 extends StatelessWidget {
  const _FactoryMobilePhase12({required this.config});
  final phase11.MobileConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FactoryOS',
        debugShowCheckedModeBanner: false,
        theme: FactoryTheme.light(),
        home: config.isConfigured
            ? const _MobileAuthGatePhase12()
            : const phase11.ConfigPage(),
      );
}

class _MobileAuthGatePhase12 extends StatelessWidget {
  const _MobileAuthGatePhase12();

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null
            ? const phase11.SignInPage()
            : _MobileBootstrapPhase12(user: session.user);
      },
    );
  }
}

class _MobileBootstrapPhase12 extends StatefulWidget {
  const _MobileBootstrapPhase12({required this.user});
  final User user;

  @override
  State<_MobileBootstrapPhase12> createState() => _MobileBootstrapPhase12State();
}

class _MobileBootstrapPhase12State extends State<_MobileBootstrapPhase12> {
  late Future<phase11.MobileBootstrapData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<phase11.MobileBootstrapData> _load() async {
    final result = await phase11.MobileRepository(
      Supabase.instance.client,
    ).bootstrap(widget.user);
    final workspace = result.workspace;
    if (workspace == null) return result;
    final modules = workspace.modules
        .where(
          (module) => WorkspaceAccessPolicy.isMobileModuleVisible(
            workspace.role,
            module.key,
          ),
        )
        .toList();
    return phase11.MobileBootstrapData(
      workspace: phase11.MobileData(
        organizationName: workspace.organizationName,
        role: workspace.role,
        factories: workspace.factories,
        modules: modules,
      ),
    );
  }

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<phase11.MobileBootstrapData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _MessagePagePhase16(
              message: '${snapshot.error}',
              onRetry: reload,
            );
          }
          final data = snapshot.requireData;
          if (data.invitation != null) {
            return phase11.MobileOnboardingPage(
              invitation: data.invitation!,
              onCompleted: reload,
            );
          }
          if (data.workspace != null) {
            return _MobileHomePhase12(data: data.workspace!);
          }
          return _MessagePagePhase16(
            message: data.message ?? 'Access unavailable.',
            onRetry: reload,
          );
        },
      );
}

class _MobileHomePhase12 extends StatefulWidget {
  const _MobileHomePhase12({required this.data});
  final phase11.MobileData data;

  @override
  State<_MobileHomePhase12> createState() => _MobileHomePhase12State();
}

class _MobileHomePhase12State extends State<_MobileHomePhase12> {
  int index = 0;
  int previousIndex = 0;
  late final ValueChanged<String> _pushRouteHandler;

  @override
  void initState() {
    super.initState();
    _pushRouteHandler = _openNotificationRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final push = PushNotificationService.instance;
      push.attachRouteHandler(_pushRouteHandler);
      unawaited(push.registerCurrentWorkspace());
    });
  }

  @override
  void dispose() {
    PushNotificationService.instance.detachRouteHandler(_pushRouteHandler);
    super.dispose();
  }

  void _openNotificationRoute(String route) {
    if (!mounted) return;
    final destination = WorkspaceAccessPolicy.mobileNotificationDestination(
      widget.data.role,
      widget.data.modules,
      route,
    );
    final Widget? page = switch (destination) {
      'maintenance' => const MaintenanceTechnicianPage(),
      'hr' => const HrSelfServicePage(),
      'inventory' => const InventoryScannerPage(),
      'production' => const ProductionExecutionPage(),
      'quality' => const QualityExecutionPage(),
      'warehouse' => const WarehouseOperationsPage(),
      'purchase' || 'sales' || 'commercial' =>
        const CommercialOperationsPage(),
      'reports' => const ReportsMobilePage(),
      'notifications' => const NotificationInboxPage(),
      'delivery' => const DeliveryDriverPage(),
      'vehicles' => const FleetDriverPage(),
      _ => null,
    };
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This notification is not available in your FactoryOS mobile workspace.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(FactoryMotion.page<void>(context, page));
  }

  void _selectTab(int value) {
    if (value == index) return;
    setState(() {
      previousIndex = index;
      index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasInventory = WorkspaceAccessPolicy.isModuleEnabled(
      widget.data.modules,
      'inventory',
    );
    final pages = <Widget>[
      _HomeTabPhase12(data: widget.data),
      const phase11.SimpleTab(title: 'Tasks', icon: Icons.task_alt),
      hasInventory
          ? const InventoryScannerPage()
          : const phase11.SimpleTab(
              title: 'Scan',
              icon: Icons.qr_code_scanner,
            ),
      NotificationInboxPage(onOpenRoute: _openNotificationRoute),
      _ProfileTabPhase16(data: widget.data),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: (index == 2 || previousIndex == 2)
            ? Duration.zero // Never retain an active scanner behind an animation.
            : FactoryMotion.duration(context, FactoryMotion.standard),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(index),
          child: pages[index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileTabPhase16 extends StatefulWidget {
  const _ProfileTabPhase16({required this.data});
  final phase11.MobileData data;

  @override
  State<_ProfileTabPhase16> createState() => _ProfileTabPhase16State();
}

class _ProfileTabPhase16State extends State<_ProfileTabPhase16> {
  bool signingOut = false;

  Future<void> _signOut() async {
    setState(() => signingOut = true);
    try {
      await PushNotificationService.instance.signOut();
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            Text(
              'Profile',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FactorySpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(widget.data.organizationName),
                subtitle: Text(widget.data.role.label),
              ),
            ),
            const SizedBox(height: FactorySpacing.md),
            for (final factory in widget.data.factories)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.factory_outlined),
                  title: Text(factory['name'] as String),
                  subtitle: Text(factory['code'] as String),
                ),
              ),
            const SizedBox(height: FactorySpacing.lg),
            FilledButton.tonalIcon(
              onPressed: signingOut ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(signingOut ? 'Signing out…' : 'Sign out'),
            ),
          ],
        ),
      );
}

class _MessagePagePhase16 extends StatelessWidget {
  const _MessagePagePhase16({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 52),
                  const SizedBox(height: FactorySpacing.md),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: FactorySpacing.md),
                  Wrap(
                    spacing: FactorySpacing.sm,
                    children: [
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                      FilledButton(
                        onPressed: () => PushNotificationService.instance.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _HomeTabPhase12 extends StatelessWidget {
  const _HomeTabPhase12({required this.data});
  final phase11.MobileData data;

  void openModule(BuildContext context, AppModule module) {
    Widget? page;
    if (module.key == 'hr') {
      page = const HrSelfServicePage();
    } else if (module.key == 'inventory') {
      page = const InventoryScannerPage();
    } else if (module.key == 'production') {
      page = const ProductionExecutionPage();
    } else if (module.key == 'quality') {
      page = const QualityExecutionPage();
    } else if (module.key == 'purchase' || module.key == 'sales') {
      page = const CommercialOperationsPage();
    } else if (module.key == 'warehouse') {
      page = const WarehouseOperationsPage();
    } else if (module.key == 'maintenance') {
      page = const MaintenanceTechnicianPage();
    } else if (module.key == 'reports') {
      page = const ReportsMobilePage();
    } else if (module.key == 'notifications') {
      page = const NotificationInboxPage();
    } else if (module.key == 'delivery') {
      if (WorkspaceAccessPolicy.canExecuteDelivery(data.role)) {
        page = const DeliveryDriverPage();
      } else {
        _notice(
          context,
          'Delivery execution is available in the Driver/Employee mobile workspace. Dispatch planning is available in FactoryOS Admin.',
        );
        return;
      }
    } else if (module.key == 'vehicles') {
      if (WorkspaceAccessPolicy.canExecuteFleet(data.role)) {
        page = const FleetDriverPage();
      } else {
        _notice(
          context,
          'Driver Fleet operations are available to the Driver role. Fleet planning is available in FactoryOS Admin.',
        );
        return;
      }
    }

    if (page == null) {
      _notice(context, '${module.name} is available through the FactoryOS workspace.');
      return;
    }
    Navigator.of(context).push(FactoryMotion.page<void>(context, page!));
  }

  void _notice(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => FactoryHomeDashboard(
        data: data,
        onOpenModule: openModule,
      );
}
