import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_operations.dart';
import 'delivery_driver.dart';
import 'fleet_driver.dart';
import 'hr_self_service.dart';
import 'inventory_scanner.dart';
import 'maintenance_technician.dart';
import 'main_phase11.dart' as phase11;
import 'production_execution.dart';
import 'quality_execution.dart';
import 'reports_mobile.dart';
import 'warehouse_operations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final management = {
      AppRole.platformOwner,
      AppRole.orgAdmin,
      AppRole.factoryManager,
      AppRole.supervisor,
    }.contains(workspace.role);
    final modules = workspace.modules
        .where((module) => module.key != 'reports' || management)
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
            return phase11.MobileMessagePage(
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
          return phase11.MobileMessagePage(
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

  @override
  Widget build(BuildContext context) {
    final hasInventory = widget.data.modules.any(
      (module) => module.key == 'inventory',
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
      const phase11.SimpleTab(
        title: 'Alerts',
        icon: Icons.notifications_none,
      ),
      phase11.ProfileTab(data: widget.data),
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
    } else if (module.key == 'delivery') {
      if (data.role == AppRole.driver || data.role == AppRole.employee) {
        page = const DeliveryDriverPage();
      } else {
        _notice(
          context,
          'Delivery execution is available in the Driver/Employee mobile workspace. Dispatch planning is available in FactoryOS Admin.',
        );
        return;
      }
    } else if (module.key == 'vehicles') {
      if (data.role == AppRole.driver) {
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
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
                        Icon(icon, color: FactoryColors.blue),
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
