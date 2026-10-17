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
}
