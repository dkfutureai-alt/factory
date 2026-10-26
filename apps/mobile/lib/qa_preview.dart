import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

import 'main_phase11.dart' show MobileData;
import 'mobile_dashboard.dart';
import 'mobile_work_hub.dart';

/// An independently compiled, OFFLINE layout review target. It never
/// initializes Supabase, Firebase, a scanner, or any remote factory workflow.
/// Never use this file as the target for a customer/store build.
void main() {
  const allowed = bool.fromEnvironment('FACTORYOS_QA_PREVIEW');
  if (!allowed) {
    throw StateError(
      'QA preview is disabled. Build explicitly with '
      '--dart-define=FACTORYOS_QA_PREVIEW=true.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FactoryOsQaPreviewApp());
}

class FactoryOsQaPreviewApp extends StatelessWidget {
  const FactoryOsQaPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FactoryOS Offline QA Preview',
        theme: FactoryTheme.light(),
        home: const FactoryOsQaPreviewShell(),
      );
}

class FactoryOsQaPreviewShell extends StatefulWidget {
  const FactoryOsQaPreviewShell({super.key});

  @override
  State<FactoryOsQaPreviewShell> createState() => _FactoryOsQaPreviewShellState();
}

class _FactoryOsQaPreviewShellState extends State<FactoryOsQaPreviewShell> {
  AppRole role = AppRole.employee;
  int tab = 0;

  static const modules = <AppModule>[
    AppModule(key: 'hr', name: 'HR & Attendance', sortOrder: 1),
    AppModule(key: 'inventory', name: 'Inventory', sortOrder: 2),
    AppModule(key: 'production', name: 'Production', sortOrder: 3),
    AppModule(key: 'quality', name: 'Quality', sortOrder: 4),
    AppModule(key: 'warehouse', name: 'Warehouse', sortOrder: 5),
    AppModule(key: 'delivery', name: 'Delivery', sortOrder: 6),
    AppModule(key: 'vehicles', name: 'Fleet', sortOrder: 7),
    AppModule(key: 'maintenance', name: 'Maintenance', sortOrder: 8),
    AppModule(key: 'reports', name: 'Reports', sortOrder: 9),
  ];

  MobileData get fixture => MobileData(
        organizationName: 'DEMO FACTORY · NOT CONNECTED',
        role: role,
        factories: const [
          <String, dynamic>{
            'name': 'Example Plant',
            'code': 'QA-001',
            'city': 'Sample City',
            'state': 'Demo Region',
          },
        ],
        modules: modules,
      );

  void previewOnly(BuildContext context, AppModule module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${module.name}: visual preview only. No data was read or changed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = fixture;
    final pages = <Widget>[
      FactoryHomeDashboard(data: data, onOpenModule: previewOnly),
      FactoryWorkHub(data: data, onOpenModule: previewOnly),
      _QaPreviewProfile(data: data),
    ];
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFFF4D6),
              padding: const EdgeInsets.symmetric(
                horizontal: FactorySpacing.md,
                vertical: FactorySpacing.xs,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: FactorySpacing.md,
                runSpacing: FactorySpacing.xxs,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: FactorySpacing.xs),
                      Flexible(
                        child: Text(
                          'OFFLINE UI PREVIEW · NO LIVE DATA',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<AppRole>(
                    value: role,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    onChanged: (next) {
                      if (next == null) return;
                      setState(() {
                        role = next;
                        tab = 0;
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                        value: AppRole.employee,
                        child: Text('Employee'),
                      ),
                      DropdownMenuItem(
                        value: AppRole.driver,
                        child: Text('Driver'),
                      ),
                      DropdownMenuItem(
                        value: AppRole.factoryManager,
                        child: Text('Manager'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: FactoryMotion.duration(
                context,
                FactoryMotion.standard,
              ),
              child: KeyedSubtree(
                key: ValueKey('${role.wireName}-$tab'),
                child: pages[tab],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (next) => setState(() => tab = next),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _QaPreviewProfile extends StatelessWidget {
  const _QaPreviewProfile({required this.data});
  final MobileData data;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              children: [
                Text(
                  'My profile',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: FactorySpacing.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(data.organizationName),
                    subtitle: Text(data.role.label),
                  ),
                ),
                const SizedBox(height: FactorySpacing.md),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Visual QA fixture'),
                    subtitle: Text(
                      'No account, attendance, inventory, fleet or delivery '
                      'operation is connected in this preview.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
