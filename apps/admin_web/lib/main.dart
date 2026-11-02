import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_management.dart';
import 'dispatch_management.dart';
import 'fleet_management.dart';
import 'hr_management.dart';
import 'inventory_management.dart';
import 'gas_container_registry.dart';
import 'maintenance_management.dart';
import 'mobile_release_management.dart';
import 'main_phase11.dart' as phase11;
import 'notification_center.dart';
import 'pilot_testing.dart';
import 'production_management.dart';
import 'purchase_sales_management.dart';
import 'quality_management.dart';
import 'reports_dashboard.dart';
import 'security_center.dart';
import 'warehouse_management.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = phase11.AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(url: config.url, publishableKey: config.key);
  }
  runApp(_FactoryAdminPhase12(config: config));
}

class _FactoryAdminPhase12 extends StatelessWidget {
  const _FactoryAdminPhase12({required this.config});
  final phase11.AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FactoryOS Admin',
        theme: FactoryTheme.light(),
        darkTheme: FactoryTheme.dark(),
        themeMode: ThemeMode.system,
        home: config.isConfigured ? const _AuthGatePhase12() : const phase11.ConfigPage(),
      );
}

class _AuthGatePhase12 extends StatelessWidget {
  const _AuthGatePhase12();

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
            : _AdminBootstrapPhase12(user: session.user);
      },
    );
  }
}

class _AdminBootstrapPhase12 extends StatefulWidget {
  const _AdminBootstrapPhase12({required this.user});
  final User user;

  @override
  State<_AdminBootstrapPhase12> createState() => _AdminBootstrapPhase12State();
}

class _AdminBootstrapPhase12State extends State<_AdminBootstrapPhase12> {
  late Future<phase11.BootstrapResult> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<phase11.BootstrapResult> _load() =>
      phase11.AdminRepository(Supabase.instance.client).bootstrap(widget.user);

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<phase11.BootstrapResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return _MessagePage(message: '${snapshot.error}', onRetry: reload);
          }
          final result = snapshot.requireData;
          if (result.invite != null) {
            return phase11.OnboardingPage(invite: result.invite!, onDone: reload);
          }
          if (result.workspace != null) {
            return _AdminShellPhase12(
              workspace: result.workspace!,
              onRefresh: reload,
            );
          }
          return _MessagePage(
            message: result.message ?? 'Access unavailable.',
            onRetry: reload,
          );
        },
      );
}

class _AdminShellPhase12 extends StatefulWidget {
  const _AdminShellPhase12({
    required this.workspace,
    required this.onRefresh,
  });

  final phase11.Workspace workspace;
  final VoidCallback onRefresh;

  @override
  State<_AdminShellPhase12> createState() => _AdminShellPhase12State();
}

class _AdminShellPhase12State extends State<_AdminShellPhase12> {
  int index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    bool enabled(String key) =>
        WorkspaceAccessPolicy.isModuleEnabled(w.modules, key);
    final dashboardEnabled = enabled('dashboard');
    final hrEnabled = enabled('hr');
    final inventoryEnabled = enabled('inventory');
    final productionEnabled = enabled('production');
    final qualityEnabled = enabled('quality');
    final warehouseEnabled = enabled('warehouse');
    final fleetEnabled = enabled('vehicles');
    final maintenanceEnabled = enabled('maintenance');
    final reportsEnabled = enabled('reports');
    final notificationsEnabled = enabled('notifications');
    final commercialEnabled = WorkspaceAccessPolicy.isCommercialEnabled(w.modules);
    final dispatchEnabled = WorkspaceAccessPolicy.isDispatchEnabled(w.modules);
    final currencyCode = w.org['currency_code'] as String? ?? 'INR';

    final tabs = <_Phase12Tab>[
      _Phase12Tab(
        'Overview',
        Icons.dashboard_outlined,
        dashboardEnabled || reportsEnabled
            ? ReportsDashboardPage(
                organizationId: w.orgId,
                actorRole: w.role,
                factories: w.factories,
                currencyCode: currencyCode,
              )
            : phase11.Overview(workspace: w),
      ),
      _Phase12Tab(
        'Factories',
        Icons.factory_outlined,
        phase11.Factories(workspace: w, onChanged: widget.onRefresh),
      ),
      if (hrEnabled)
        _Phase12Tab(
          'HR',
          Icons.groups_2_outlined,
          HrManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (inventoryEnabled)
        _Phase12Tab(
          'Inventory',
          Icons.inventory_2_outlined,
          InventoryManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (inventoryEnabled)
        _Phase12Tab(
          'Cylinders',
          Icons.qr_code_2_outlined,
          GasContainerRegistryPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (productionEnabled)
        _Phase12Tab(
          'Production',
          Icons.precision_manufacturing_outlined,
          ProductionManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (qualityEnabled)
        _Phase12Tab(
          'Quality',
          Icons.verified_user_outlined,
          QualityManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (commercialEnabled)
        _Phase12Tab(
          'Purchase & Sales',
          Icons.sync_alt,
          PurchaseSalesManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (warehouseEnabled)
        _Phase12Tab(
          'Warehouse',
          Icons.warehouse_outlined,
          WarehouseManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (fleetEnabled)
        _Phase12Tab(
          'Fleet',
          Icons.local_shipping_outlined,
          FleetManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (dispatchEnabled)
        _Phase12Tab(
          'Dispatch',
          Icons.route_outlined,
          DispatchManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (maintenanceEnabled)
        _Phase12Tab(
          'Maintenance',
          Icons.build_circle_outlined,
          MaintenanceManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (reportsEnabled)
        _Phase12Tab(
          'Reports',
          Icons.bar_chart_outlined,
          ReportsDashboardPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
            currencyCode: currencyCode,
            showReportWorkspace: true,
          ),
        ),
      if (notificationsEnabled)
        _Phase12Tab(
          'Notifications',
          Icons.notifications_active_outlined,
          NotificationCenterPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (w.role.canUseAdminPortal)
        _Phase12Tab(
          'Audit & Security',
          Icons.admin_panel_settings_outlined,
          SecurityCenterPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (w.role.canManageAccess)
        _Phase12Tab(
          'Pilot Testing',
          Icons.fact_check_outlined,
          PilotTestingPage(organizationId: w.orgId),
        ),
      if (w.role.canManageAccess)
        _Phase12Tab(
          'Users',
          Icons.groups_outlined,
          AccessManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (w.role == AppRole.platformOwner)
        _Phase12Tab(
          'App Updates',
          Icons.system_update_alt,
          const MobileReleaseManagementPage(),
        ),
      _Phase12Tab(
        'Modules',
        Icons.widgets_outlined,
        phase11.ModuleList(modules: w.modules),
      ),
      _Phase12Tab(
        'Organization',
        Icons.settings_outlined,
        phase11.Organization(workspace: w, onChanged: widget.onRefresh),
      ),
    ];

    if (index >= tabs.length) index = 0;
    final compact = MediaQuery.sizeOf(context).width < 900;
    if (compact) {
      // NavigationBar is for a few high-frequency destinations, not 15+
      // enterprise modules. All other authorized modules stay in the drawer.
      final quickTabs = <int>[0];
      for (final label in const ['Inventory', 'Dispatch']) {
        final tabIndex = tabs.indexWhere((tab) => tab.label == label);
        if (tabIndex >= 0 && !quickTabs.contains(tabIndex)) {
          quickTabs.add(tabIndex);
        }
      }
      final quickSelected = quickTabs.indexOf(index);
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            w.org['name'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: _AdminModuleMenu(
              organizationName: w.org['name'] as String,
              tabs: tabs,
              selectedIndex: index,
              onSelected: (value) {
                Navigator.of(context).pop();
                setState(() => index = value);
              },
            ),
          ),
        ),
        body: tabs[index].page,
        bottomNavigationBar: NavigationBar(
          selectedIndex:
              quickSelected < 0 ? quickTabs.length : quickSelected,
          onDestinationSelected: (value) {
            if (value == quickTabs.length) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => index = quickTabs[value]);
            }
          },
          destinations: [
            for (final tabIndex in quickTabs)
              NavigationDestination(
                icon: Icon(tabs[tabIndex].icon),
                label: tabs[tabIndex].label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              label: 'All modules',
            ),
          ],
        ),
      );
    }

    // Scrolling sidebar is essential when many factory modules are enabled.
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: _AdminModuleMenu(
                organizationName: w.org['name'] as String,
                tabs: tabs,
                selectedIndex: index,
                onSelected: (value) => setState(() => index = value),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: tabs[index].page),
          ],
        ),
      ),
    );
  }
}

class _Phase12Tab {
  const _Phase12Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class _AdminModuleMenu extends StatelessWidget {
  const _AdminModuleMenu({
    required this.organizationName,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String organizationName;
  final List<_Phase12Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(vertical: FactorySpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.all(FactorySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FactoryOS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: FactorySpacing.xs),
                Text(
                  organizationName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(),
          for (var i = 0; i < tabs.length; i++)
            ListTile(
              leading: Icon(tabs[i].icon),
              title: Text(tabs[i].label),
              selected: i == selectedIndex,
              minTileHeight: 48,
              onTap: () => onSelected(i),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      );
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 48),
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
                      onPressed: () => Supabase.instance.client.auth.signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
