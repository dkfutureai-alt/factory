import 'app_module.dart';
import 'app_role.dart';

class WorkspaceAccessPolicy {
  const WorkspaceAccessPolicy._();

  static bool isManagementRole(AppRole role) => switch (role) {
        AppRole.platformOwner ||
        AppRole.orgAdmin ||
        AppRole.factoryManager ||
        AppRole.supervisor =>
          true,
        _ => false,
      };

  static bool isModuleEnabled(Iterable<AppModule> modules, String key) =>
      modules.any((module) => module.key == key);

  static bool isMobileModuleVisible(AppRole role, String moduleKey) =>
      moduleKey != 'reports' || isManagementRole(role);

  static bool canExecuteDelivery(AppRole role) =>
      role == AppRole.driver || role == AppRole.employee;

  static bool canExecuteFleet(AppRole role) => role == AppRole.driver;

  static bool isCommercialEnabled(Iterable<AppModule> modules) =>
      isModuleEnabled(modules, 'purchase') || isModuleEnabled(modules, 'sales');

  static bool isDispatchEnabled(Iterable<AppModule> modules) =>
      isModuleEnabled(modules, 'delivery') &&
      isModuleEnabled(modules, 'warehouse') &&
      isModuleEnabled(modules, 'vehicles') &&
      isModuleEnabled(modules, 'sales');

  /// Resolves a notification route only when its module is available in the
  /// authenticated workspace. This is UI navigation filtering, not an RLS
  /// replacement: every destination must keep enforcing database permissions.
  ///
  /// The first path segment must match exactly (never use startsWith), so
  /// /sales-preview cannot accidentally open the Sales workspace.
  static String? mobileNotificationDestination(
    AppRole role,
    Iterable<AppModule> modules,
    String route,
  ) {
    final path = route.trim().split(RegExp(r'[?#]')).first;
    final parts = path.split('/');
    if (parts.length < 2 || parts.first.isNotEmpty || parts[1].isEmpty) {
      return null;
    }
    final section = parts[1];
    final destination = switch (section) {
      'hr' ||
      'inventory' ||
      'production' ||
      'quality' ||
      'warehouse' ||
      'maintenance' ||
      'purchase' ||
      'sales' ||
      'reports' ||
      'notifications' => section,
      'commercial' => 'commercial',
      'dispatch' || 'delivery' => 'delivery',
      'fleet' || 'vehicles' => 'vehicles',
      _ => null,
    };
    if (destination == null) return null;
    if (destination == 'commercial') {
      return isCommercialEnabled(modules) ? destination : null;
    }
    if (destination == 'delivery' && !canExecuteDelivery(role)) return null;
    if (destination == 'vehicles' && !canExecuteFleet(role)) return null;
    if (destination == 'reports' && !isMobileModuleVisible(role, 'reports')) {
      return null;
    }
    return isModuleEnabled(modules, destination) ? destination : null;
  }
}
