import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire roles resolve to expected enum values', () {
    expect(AppRole.fromWireName('org_admin'), AppRole.orgAdmin);
    expect(AppRole.fromWireName('driver'), AppRole.driver);
  });

  test('admin portal remains restricted to management roles', () {
    expect(AppRole.orgAdmin.canUseAdminPortal, isTrue);
    expect(AppRole.factoryManager.canUseAdminPortal, isTrue);
    expect(AppRole.employee.canUseAdminPortal, isFalse);
    expect(AppRole.driver.canUseAdminPortal, isFalse);
  });

  test('organization setup changes remain admin-only', () {
    expect(AppRole.platformOwner.canManageOrganizationSetup, isTrue);
    expect(AppRole.orgAdmin.canManageOrganizationSetup, isTrue);
    expect(AppRole.factoryManager.canManageOrganizationSetup, isFalse);
  });

  test('access management remains admin-only', () {
    expect(AppRole.platformOwner.canManageAccess, isTrue);
    expect(AppRole.orgAdmin.canManageAccess, isTrue);
    expect(AppRole.factoryManager.canManageAccess, isFalse);
  });

  test('factory-scoped roles require assignments', () {
    expect(AppRole.factoryManager.requiresFactoryAssignment, isTrue);
    expect(AppRole.supervisor.requiresFactoryAssignment, isTrue);
    expect(AppRole.employee.requiresFactoryAssignment, isTrue);
    expect(AppRole.driver.requiresFactoryAssignment, isTrue);
    expect(AppRole.orgAdmin.requiresFactoryAssignment, isFalse);
    expect(AppRole.viewer.requiresFactoryAssignment, isFalse);
  });
}
