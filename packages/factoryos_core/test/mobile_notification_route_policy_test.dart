import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = <AppModule>[
    AppModule(key: 'hr', name: 'HR', sortOrder: 1),
    AppModule(key: 'inventory', name: 'Inventory', sortOrder: 2),
    AppModule(key: 'production', name: 'Production', sortOrder: 3),
    AppModule(key: 'quality', name: 'Quality', sortOrder: 4),
    AppModule(key: 'warehouse', name: 'Warehouse', sortOrder: 5),
    AppModule(key: 'purchase', name: 'Purchase', sortOrder: 6),
    AppModule(key: 'sales', name: 'Sales', sortOrder: 7),
    AppModule(key: 'delivery', name: 'Delivery', sortOrder: 8),
    AppModule(key: 'vehicles', name: 'Fleet', sortOrder: 9),
    AppModule(key: 'maintenance', name: 'Maintenance', sortOrder: 10),
    AppModule(key: 'reports', name: 'Reports', sortOrder: 11),
    AppModule(key: 'notifications', name: 'Notifications', sortOrder: 12),
  ];

  String? destination(
    String route, {
    AppRole role = AppRole.employee,
    Iterable<AppModule> enabled = modules,
  }) =>
      WorkspaceAccessPolicy.mobileNotificationDestination(role, enabled, route);

  test('enabled operational routes resolve to expected mobile workspaces', () {
    const routes = <String, String>{
      '/hr/attendance': 'hr',
      '/inventory/stock': 'inventory',
      '/production/batch': 'production',
      '/quality/checklist': 'quality',
      '/warehouse/picking': 'warehouse',
      '/maintenance/asset': 'maintenance',
      '/purchase/order': 'purchase',
      '/sales/quote': 'sales',
      '/commercial': 'commercial',
      '/notifications': 'notifications',
    };
    for (final entry in routes.entries) {
      expect(destination(entry.key), entry.value, reason: entry.key);
    }
  });

  test('disabled modules cannot be opened from a notification', () {
    const paths = <String>[
      '/hr', '/inventory', '/production', '/quality', '/warehouse',
      '/maintenance', '/purchase', '/sales', '/commercial',
      '/notifications', '/reports', '/delivery', '/fleet', '/dispatch',
    ];
    for (final route in paths) {
      expect(destination(route, enabled: const []), isNull, reason: route);
    }
  });

  test('first segment must match exactly, not by prefix or substring', () {
    const malformed = <String>[
      '', 'hr', '//hr', 'https://example.com/hr',
      '/hr-unrelated', '/sales-preview', '/inventoryShadow',
      '/reporting', '/fleet-extra', '/delivery-other', '/unknown',
    ];
    for (final route in malformed) {
      expect(destination(route), isNull, reason: route);
    }
  });

  test('query and fragment do not bypass module checks', () {
    expect(destination('/hr/attendance?source=push#item'), 'hr');
    expect(destination('/hr?next=/sales', enabled: const []), isNull);
    expect(destination('/sales-preview?source=push'), isNull);
  });

  test('purchase and sales are independently enabled', () {
    const purchase = [
      AppModule(key: 'purchase', name: 'Purchase', sortOrder: 1),
    ];
    expect(destination('/purchase', enabled: purchase), 'purchase');
    expect(destination('/sales', enabled: purchase), isNull);
    expect(destination('/commercial', enabled: purchase), 'commercial');

    const sales = [
      AppModule(key: 'sales', name: 'Sales', sortOrder: 1),
    ];
    expect(destination('/sales', enabled: sales), 'sales');
    expect(destination('/purchase', enabled: sales), isNull);
    expect(destination('/commercial', enabled: sales), 'commercial');
  });

  test('reports route requires enabled module AND management role', () {
    for (final role in AppRole.values) {
      final allowed = WorkspaceAccessPolicy.isManagementRole(role);
      expect(
        destination('/reports/overview', role: role),
        allowed ? 'reports' : null,
        reason: role.wireName,
      );
    }
    expect(
      destination('/reports', role: AppRole.orgAdmin, enabled: const []),
      isNull,
    );
  });

  test('fleet route requires driver role and vehicles module', () {
    for (final role in AppRole.values) {
      expect(
        destination('/fleet/trips', role: role),
        role == AppRole.driver ? 'vehicles' : null,
        reason: role.wireName,
      );
    }
    expect(destination('/vehicles', role: AppRole.driver), 'vehicles');
    expect(
      destination('/vehicles', role: AppRole.driver, enabled: const []),
      isNull,
    );
  });

  test('delivery and dispatch routes require permitted execution role', () {
    for (final role in AppRole.values) {
      final allowed = WorkspaceAccessPolicy.canExecuteDelivery(role);
      expect(
        destination('/delivery/stop', role: role),
        allowed ? 'delivery' : null,
        reason: role.wireName,
      );
      expect(
        destination('/dispatch/trip', role: role),
        allowed ? 'delivery' : null,
        reason: role.wireName,
      );
    }
    expect(
      destination('/dispatch', role: AppRole.driver, enabled: const []),
      isNull,
    );
  });

  test('unrelated enabled modules cannot grant access to target module', () {
    const onlyInventory = [
      AppModule(key: 'inventory', name: 'Inventory', sortOrder: 1),
    ];
    expect(destination('/inventory', enabled: onlyInventory), 'inventory');
    expect(destination('/maintenance', enabled: onlyInventory), isNull);
    expect(destination('/notifications', enabled: onlyInventory), isNull);
  });
}
