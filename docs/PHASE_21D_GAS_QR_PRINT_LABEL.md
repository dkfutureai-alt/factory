# Phase 21D — Print Cylinder/Dura QR Identity Label

**Scope:** generate a compact **90 × 55 mm PDF label** from an already registered FactoryOS container. This feature does not perform a stock transaction, update custody, make an inspection entry or certify a pressure vessel.

## Workflow

1. Admin → **Cylinders** → select the correct factory → registered container → **Print QR identity label**.
2. The app validates the exact FactoryOS-generated `FA-` + 32-hex QR token, the normalized 3–80 character serial and supported container type.
3. Generate the PDF entirely locally using open-source `pdf`, and open the browser/OS printer dialog via `printing`. No asset names, owner/customer contact details or cloud upload appear in the label.
4. The label includes a high-contrast QR, readable serial, cylinder/Dura type and an explicit **IDENTITY ONLY / NOT SAFETY CERTIFIED** warning.
5. Choose a **suitable durable label stock** and printer. Print cancellation or a successful software dialog does not prove the label was applied. Verify the physical scan on real devices with the correct organization logged in, inspect readability on curved metal surfaces and keep safety/certification markings separate.

## Tests

- `apps/admin_web/test/gas_container_qr_label_test.dart`: generated PDF header, normal and 80-character serials, malformed QR denial, unsafe serial rejection, unsupported types.
- Flutter Application Quality: Admin analyzer/tests/web build after resolving packages.
- Physical QR acceptance (Android/iOS, camera permissions, scan distance/lighting, abrasion, label durability and correct factory association) **remains pending**.

**Production:** QR print requires deployed FactoryOS app, migrations through the latest source version, appropriate login/RLS and physical QA. It is not an export of stock or a regulatory conformity certificate. No Salon or Janseva resources may be changed.
