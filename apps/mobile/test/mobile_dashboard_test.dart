import 'package:factoryos_core/factoryos_core.dart';
import 'package:factoryos_mobile/main_phase11.dart' show MobileData;
import 'package:factoryos_mobile/mobile_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = <AppModule>[
    AppModule(key: 'inventory', name: 'Inventory', sortOrder: 1),
    AppModule(key: 'hr', name: 'HR', sortOrder: 2),
  ];

  testWidgets('dashboard displays real bootstrap counts and opens a module',
      (tester) async {
    AppModule? opened;
    const data = MobileData(
      organizationName: 'Example Works',
      role: AppRole.employee,
      factories: [
        {'name': 'North Plant', 'code': 'NP-1', 'city': 'Pune'},
      ],
      modules: modules,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: Scaffold(
          body: FactoryHomeDashboard(
            data: data,
            onOpenModule: (_, module) => opened = module,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example Works'), findsOneWidget);
    expect(find.text('North Plant'), findsOneWidget);
    expect(find.text('2 workspaces'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);
    await tester.tap(find.text('Inventory'));
    expect(opened?.key, 'inventory');
  });

  testWidgets('narrow workspace does not overflow and shows empty state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = MobileData(
      organizationName: 'Example',
      role: AppRole.employee,
      factories: [],
      modules: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: Scaffold(
          body: FactoryHomeDashboard(
            data: data,
            onOpenModule: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No factory assigned'), findsOneWidget);
    expect(find.text('No modules are enabled for this role.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard excludes unsupported and role-blocked modules',
      (tester) async {
    const data = MobileData(
      organizationName: 'Example Works',
      role: AppRole.employee,
      factories: [],
      modules: [
        AppModule(key: 'hr', name: 'Human Resources', sortOrder: 1),
        AppModule(key: 'reports', name: 'Reports', sortOrder: 2),
        AppModule(key: 'vehicles', name: 'Fleet', sortOrder: 3),
        AppModule(key: 'unknown', name: 'Unfinished Module', sortOrder: 4),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: Scaffold(
          body: FactoryHomeDashboard(
            data: data,
            onOpenModule: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 workspace'), findsOneWidget);
    expect(find.text('1 available'), findsOneWidget);
    expect(find.text('Human Resources'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Fleet'), findsNothing);
    expect(find.text('Unfinished Module'), findsNothing);
  });

  testWidgets('dashboard supports large accessibility text in RTL on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = MobileData(
      organizationName: 'A Long Factory Organization Name',
      role: AppRole.factoryManager,
      factories: [
        {'name': 'Large Manufacturing Plant', 'code': 'F-001'},
      ],
      modules: [
        AppModule(key: 'production', name: 'Production Management', sortOrder: 1),
        AppModule(key: 'inventory', name: 'Inventory Tracking', sortOrder: 2),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: FactoryTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: FactoryHomeDashboard(
              data: data,
              onOpenModule: (_, _) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('A Long Factory Organization Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
