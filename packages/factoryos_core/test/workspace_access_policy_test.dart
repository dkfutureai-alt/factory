import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = <AppModule>[
    AppModule(key: 'purchase', name: 'Purchase', sortOrder: 1),
    AppModule(key: 'sales', name: 'Sales', sortOrder: 2),
    AppModule(key: 'warehouse', name: 'Warehouse', sortOrder: 3),
    AppModule(key: 'vehicles', name: 'Fleet', sortOrder: 4),
    AppModule(key: 'delivery', name: 'Delivery', sortOrder: 5),
    AppModule(key: 'reports', name: 'Reports', sortOrder: 6),
  ];

  test('management reporting visibility matches the approved mobile role model', () {
    for (final role in <AppRole>[
      AppRole.platformOwner,
      AppRole.orgAdmin,
      AppRole.factoryManager,
      AppRole.supervisor,
    ]) {
      expect(
        WorkspaceAccessPolicy.isMobileModuleVisible(role, 'reports'),
        isTrue,
        reason: '${role.wireName} should retain management reports',
      );
    }

    for (final role in <AppRole>[
      AppRole.employee,
      AppRole.driver,
      AppRole.viewer,
    ]) {
      expect(
        WorkspaceAccessPolicy.isMobileModuleVisible(role, 'reports'),
        isFalse,
        reason: '${role.wireName} should not receive management reports',
      );
    }
  });

  test('non-report mobile modules remain visible when enabled', () {
    for (final role in AppRole.values) {
      expect(
        WorkspaceAccessPolicy.isMobileModuleVisible(role, 'inventory'),
        isTrue,
      );
    }
  });

  test('delivery execution remains limited to employee and driver roles', () {
    expect(WorkspaceAccessPolicy.canExecuteDelivery(AppRole.employee), isTrue);
    expect(WorkspaceAccessPolicy.canExecuteDelivery(AppRole.driver), isTrue);
    expect(WorkspaceAccessPolicy.canExecuteDelivery(AppRole.supervisor), isFalse);
    expect(WorkspaceAccessPolicy.canExecuteDelivery(AppRole.factoryManager), isFalse);
  });

  test('fleet execution remains driver-only', () {
    for (final role in AppRole.values) {
      expect(
        WorkspaceAccessPolicy.canExecuteFleet(role),
        role == AppRole.driver,
      );
    }
  });

  test('commercial navigation is available when purchase or sales is enabled', () {
    expect(WorkspaceAccessPolicy.isCommercialEnabled(modules), isTrue);
    expect(
      WorkspaceAccessPolicy.isCommercialEnabled(const [
        AppModule(key: 'purchase', name: 'Purchase', sortOrder: 1),
      ]),
      isTrue,
    );
    expect(
      WorkspaceAccessPolicy.isCommercialEnabled(const [
        AppModule(key: 'inventory', name: 'Inventory', sortOrder: 1),
      ]),
      isFalse,
    );
  });

  test('dispatch navigation requires the complete operational dependency set', () {
    expect(WorkspaceAccessPolicy.isDispatchEnabled(modules), isTrue);

    const requiredKeys = <String>{'delivery', 'warehouse', 'vehicles', 'sales'};
    for (final missingKey in requiredKeys) {
      final incomplete = modules
          .where((module) => module.key != missingKey)
          .toList(growable: false);
      expect(
        WorkspaceAccessPolicy.isDispatchEnabled(incomplete),
        isFalse,
        reason: 'Dispatch must stay hidden without $missingKey',
      );
    }
  });
}
