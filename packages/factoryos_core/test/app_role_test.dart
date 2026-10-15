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
    expect(AppRole.orgAdmin.canManageFactories, isTrue);
    expect(AppRole.factoryManager.canManageFactories, isFalse);
    expect(AppRole.supervisor.canManageOrganizationSetup, isFalse);
  });
}
