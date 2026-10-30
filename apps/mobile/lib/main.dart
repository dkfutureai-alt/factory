import 'dart:async';

import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_operations.dart';
import 'customer_pilot.dart';
import 'delivery_driver.dart';
import 'fleet_driver.dart';
import 'hr_self_service.dart';
import 'inventory_scanner.dart';
import 'maintenance_technician.dart';
import 'mobile_session_identity.dart';
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
        darkTheme: FactoryTheme.dark(),
        themeMode: ThemeMode.system,
        home: config.isConfigured
            ? const _MobileAuthGatePhase12()
            : const phase11.ConfigPage(),
      );
}

class _MobileAuthGatePhase12 extends StatefulWidget {
  const _MobileAuthGatePhase12();

  @override
  State<_MobileAuthGatePhase12> createState() => _MobileAuthGatePhase12State();
}

class _MobileAuthGatePhase12State extends State<_MobileAuthGatePhase12> {
  late final MobileAccountChangeTracker _accountChanges;

  @override
  void initState() {
    super.initState();
    _accountChanges = MobileAccountChangeTracker(
      Supabase.instance.client.auth.currentUser?.id,
    );
  }

  void _resetNavigationOnAccountChange(String? userId) {
    if (!_accountChanges.changedTo(userId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // All pushed module routes (and modal sheets) belong to the old user.
      // Pop them before the newly authenticated workspace can be used.
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

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
        _resetNavigationOnAccountChange(session?.user.id);
        return session == null
            ? const phase11.SignInPage()
            : _MobileBootstrapPhase12(
                key: ValueKey(session.user.id),
                user: session.user,
              );
      },
    );
  }
}

class _MobileBootstrapPhase12 extends StatefulWidget {
  const _MobileBootstrapPhase12({required this.user, super.key});
  final User user;

  @override
  State<_MobileBootstrapPhase12> createState() => _MobileBootstrapPhase12State();
}

class _MobileBootstrapPhase12State extends State<_MobileBootstrapPhase12>
    with WidgetsBindingObserver {
  late Future<phase11.MobileBootstrapData> future;
  late MobileSessionIdentity _identity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _identity = MobileSessionIdentity(widget.user.id);
    future = _load();
  }

  @override
  void didUpdateWidget(covariant _MobileBootstrapPhase12 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _identity = MobileSessionIdentity(widget.user.id);
      reload();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A factory assignment or role may have been revoked while suspended.
      // Rebuild every module from current server-authorized memberships.
      reload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<phase11.MobileBootstrapData> _load() async {
    final identity = MobileSessionIdentity(widget.user.id);
    final client = Supabase.instance.client;
    identity.requireCurrent(client.auth.currentUser?.id);
    final result = await phase11.MobileRepository(client).bootstrap(widget.user);
    identity.requireCurrent(client.auth.currentUser?.id);
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
    identity.requireCurrent(client.auth.currentUser?.id);
    return phase11.MobileBootstrapData(
      workspace: phase11.MobileData(
        organizationId: workspace.organizationId,
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
          if (!_identity.matches(Supabase.instance.client.auth.currentUser?.id)) {
            return const Scaffold(
              body: Center(child: Text('Account changed. Reload your session.')),
            );
          }
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
            return _MobileHomePhase12(
              key: ObjectKey(future),
              data: data.workspace!,
            );
          }
          return _MessagePagePhase16(
            message: data.message ?? 'Access unavailable.',
            onRetry: reload,
          );
        },
      );
}

class _MobileHomePhase12 extends StatefulWidget {
  const _MobileHomePhase12({required this.data, super.key});
  final phase11.MobileData data;

  @override
  State<_MobileHomePhase12> createState() => _MobileHomePhase12State();
}

class _MobileHomePhase12State extends State<_MobileHomePhase12> {
  int index = 0;
  late final ValueChanged<String> _pushRouteHandler;

  @override
  void initState() {
    super.initState();
    _pushRouteHandler = _openNotificationRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final push = PushNotificationService.instance;
      push.attachRouteHandler(
        _pushRouteHandler,
        organizationId: widget.data.organizationId,
        userId: Supabase.instance.client.auth.currentUser?.id ?? '',
      );
      unawaited(push.registerCurrentWorkspace(
        organizationId: widget.data.organizationId,
      ));
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
      'inventory' => InventoryScannerPage(organizationId: widget.data.organizationId),
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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
          ? InventoryScannerPage(organizationId: widget.data.organizationId)
          : const phase11.SimpleTab(
              title: 'Scan',
              icon: Icons.qr_code_scanner,
            ),
      NotificationInboxPage(onOpenRoute: _openNotificationRoute),
      _ProfileTabPhase16(data: widget.data),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Customer pilot'),
                subtitle: const Text('Join a test and report real workflow results'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerPilotPage(
                      organizationId: widget.data.organizationId,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: FactorySpacing.md),
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
      page = InventoryScannerPage(organizationId: data.organizationId);
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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page!));
  }

  void _notice(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final primaryFactory = data.factories.isEmpty ? null : data.factories.first;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.md),
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.factory_outlined)),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.organizationName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(data.role.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(
                primaryFactory == null
                    ? 'No factory assigned'
                    : primaryFactory['name'] as String,
              ),
              subtitle: primaryFactory == null
                  ? null
                  : Text(
                      [
                        primaryFactory['code'],
                        primaryFactory['city'],
                        primaryFactory['state'],
                      ].whereType<String>().join(' · '),
                    ),
            ),
          ),
          const SizedBox(height: FactorySpacing.lg),
          Text(
            'Your modules',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: FactorySpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = FactoryLayout.metricColumns(
                context,
                constraints.maxWidth,
              );
              final largeText =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.modules.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: largeText ? 172 : (columns == 1 ? 112 : 144),
              crossAxisSpacing: FactorySpacing.sm,
              mainAxisSpacing: FactorySpacing.sm,
            ),
            itemBuilder: (context, moduleIndex) {
              final module = data.modules[moduleIndex];
              final icon = switch (module.key) {
                'hr' => Icons.groups_2_outlined,
                'inventory' => Icons.inventory_2_outlined,
                'production' => Icons.precision_manufacturing_outlined,
                'quality' => Icons.verified_user_outlined,
                'warehouse' => Icons.warehouse_outlined,
                'vehicles' => Icons.local_shipping_outlined,
                'delivery' => Icons.route_outlined,
                'maintenance' => Icons.build_circle_outlined,
                'reports' => Icons.bar_chart_outlined,
                'notifications' => Icons.notifications_active_outlined,
                'dashboard' => Icons.dashboard_outlined,
                _ => Icons.widgets_outlined,
              };
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(FactoryRadius.lg),
                  onTap: () => openModule(context, module),
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: FactorySpacing.sm),
                        Text(
                          module.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
            },
          ),
          if (data.modules.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(FactorySpacing.lg),
                child: Text('No modules are available for this role.'),
              ),
            ),
        ],
      ),
    );
  }
}
