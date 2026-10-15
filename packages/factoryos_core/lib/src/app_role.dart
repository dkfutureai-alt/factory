enum AppRole {
  platformOwner('platform_owner', 'Platform Owner'),
  orgAdmin('org_admin', 'Organization Admin'),
  factoryManager('factory_manager', 'Factory Manager'),
  supervisor('supervisor', 'Supervisor'),
  employee('employee', 'Employee'),
  driver('driver', 'Driver'),
  viewer('viewer', 'Viewer');

  const AppRole(this.wireName, this.label);

  final String wireName;
  final String label;

  static AppRole fromWireName(String value) {
    return AppRole.values.firstWhere(
      (role) => role.wireName == value,
      orElse: () => AppRole.viewer,
    );
  }

  bool get canUseAdminPortal => switch (this) {
        AppRole.platformOwner ||
        AppRole.orgAdmin ||
        AppRole.factoryManager => true,
        _ => false,
      };

  bool get canManagePeople => switch (this) {
        AppRole.platformOwner ||
        AppRole.orgAdmin ||
        AppRole.factoryManager => true,
        _ => false,
      };
}
