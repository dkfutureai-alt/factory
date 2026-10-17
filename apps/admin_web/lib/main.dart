import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_management.dart';
import 'dispatch_management.dart';
import 'fleet_management.dart';
import 'hr_management.dart';
import 'inventory_management.dart';
import 'maintenance_management.dart';
import 'main_legacy.dart' as legacy;
import 'production_management.dart';
import 'purchase_sales_management.dart';
import 'quality_management.dart';
import 'warehouse_management.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const currentKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final key = currentKey.isNotEmpty ? currentKey : legacyKey;
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: key);
  }
  runApp(_FactoryAdminV11(configured: url.isNotEmpty && key.isNotEmpty));
}

class _FactoryAdminV11 extends StatelessWidget {
  const _FactoryAdminV11({required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FactoryOS Admin',
        theme: FactoryTheme.light(),
        home: configured ? const _AuthGateV11() : const legacy.ConfigPage(),
      );
}

class _AuthGateV11 extends StatelessWidget {
  const _AuthGateV11();

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
            ? const legacy.SignInPage()
            : _AdminBootstrapV11(user: session.user);
      },
    );
  }
}

class _AdminBootstrapV11 extends StatefulWidget {
  const _AdminBootstrapV11({required this.user});
  final User user;

  @override
  State<_AdminBootstrapV11> createState() => _AdminBootstrapV11State();
}

class _AdminBootstrapV11State extends State<_AdminBootstrapV11> {
  late Future<legacy.BootstrapResult> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<legacy.BootstrapResult> _load() =>
      legacy.AdminRepository(Supabase.instance.client).bootstrap(widget.user);

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<legacy.BootstrapResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _MessagePage(message: '${snapshot.error}', onRetry: reload);
          }
          final result = snapshot.requireData;
          if (result.invite != null) {
            return legacy.OnboardingPage(
              invite: result.invite!,
              onDone: reload,
            );
          }
          if (result.workspace != null) {
            return _AdminShellV11(
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

class _AdminShellV11 extends StatefulWidget {
  const _AdminShellV11({
    required this.workspace,
    required this.onRefresh,
  });

  final legacy.Workspace workspace;
  final VoidCallback onRefresh;

  @override
  State<_AdminShellV11> createState() => _AdminShellV11State();
}

class _AdminShellV11State extends State<_AdminShellV11> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    bool enabled(String key) => w.modules.any((module) => module.key == key);
    final commercialEnabled = enabled('purchase') || enabled('sales');
    final tabs = <_V11Tab>[
      _V11Tab('Overview', Icons.dashboard_outlined, legacy.Overview(workspace: w)),
      _V11Tab(
        'Factories',
        Icons.factory_outlined,
        legacy.Factories(workspace: w, onChanged: widget.onRefresh),
      ),
      if (enabled('hr'))
        _V11Tab(
          'HR',
          Icons.groups_2_outlined,
          HrManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('inventory'))
        _V11Tab(
          'Inventory',
          Icons.inventory_2_outlined,
          InventoryManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('production'))
        _V11Tab(
          'Production',
          Icons.precision_manufacturing_outlined,
          ProductionManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('quality'))
        _V11Tab(
          'Quality',
          Icons.verified_user_outlined,
          QualityManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (commercialEnabled)
        _V11Tab(
          'Purchase & Sales',
          Icons.sync_alt,
          PurchaseSalesManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('warehouse'))
        _V11Tab(
          'Warehouse',
          Icons.warehouse_outlined,
          WarehouseManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('vehicles'))
        _V11Tab(
          'Fleet',
          Icons.local_shipping_outlined,
          FleetManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('delivery') &&
          enabled('warehouse') &&
          enabled('vehicles') &&
          enabled('sales'))
        _V11Tab(
          'Dispatch',
          Icons.route_outlined,
          DispatchManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (enabled('maintenance'))
        _V11Tab(
          'Maintenance',
          Icons.build_outlined,
          MaintenanceManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      if (w.role.canManageAccess)
        _V11Tab(
          'Users',
          Icons.groups_outlined,
          AccessManagementPage(
            organizationId: w.orgId,
            actorRole: w.role,
            factories: w.factories,
          ),
        ),
      _V11Tab(
        'Modules',
        Icons.widgets_outlined,
        legacy.ModuleList(modules: w.modules),
      ),
      _V11Tab(
        'Organization',
        Icons.settings_outlined,
        legacy.Organization(workspace: w, onChanged: widget.onRefresh),
      ),
    ];

    if (index >= tabs.length) index = 0;
    final compact = MediaQuery.sizeOf(context).width < 900;
    if (compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(w.org['name'] as String),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: tabs[index].page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: tabs
              .map(
                (tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ),
              )
              .toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 1160,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            leading: const Padding(
              padding: EdgeInsets.all(FactorySpacing.lg),
              child: Text(
                'FactoryOS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            destinations: tabs
                .map(
                  (tab) => NavigationRailDestination(
                    icon: Icon(tab.icon),
                    label: Text(tab.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: tabs[index].page),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}

class _V11Tab {
  const _V11Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
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
