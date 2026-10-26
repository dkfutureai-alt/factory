# FactoryOS Real Customer Pilot — Opt-In Test Program

## Purpose

Test the actual FactoryOS application with **consenting real customer representatives** using their own emails, Android/iOS devices, and assigned factory roles. No invented customer names, contact details or accounts. Never send unsolicited invitations.

## Enrollment

1. Owner configures dedicated FactoryOS backend, HTTPS Admin hosting and SMTP; confirm dedicated project ref, secure Auth redirects and no unrelated production accounts.
2. Create a **separate authorized pilot organization/factory** and invite only people who have explicitly agreed to participate through the existing **Users** screen. A business owner or factory representative should authorize use of non-sensitive pilot business data.
3. User opens the real invitation, completes onboarding, signs in on mobile and opens **Profile → Customer pilot**.
4. User reads the pilot consent text and actively selects **I agree to join this test**. No account is enrolled automatically.
5. User executes the workflows available to their assigned role and submits **Passed / Failed / Blocked** feedback per workflow. Limit comments to 1,000 characters and exclude personal and customer secrets.
6. Org Admin or Platform Owner opens **Admin → Pilot Testing**, views signed-up testers and scoped results. A blocker is **not** an automatic success.
7. User can select **Leave pilot and erase my reports** from mobile. Reports are cascade-deleted. Membership and unrelated factory records remain intact.

## Coverage and acceptance

- Roles: organization admin, factory manager, supervisor, employee, driver, viewer (at least one real consenting tester per relevant role).
- Test onboarding, HR, inventory, production, quality, purchasing, sales, warehouse, fleet, dispatch/POD, maintenance, reports, push notification and security access denial.
- Verify two organizations and separate factories cannot see or mutate each other's pilot data or business records.
- Test weak connectivity, session expiry, barcode/QR scanning, sign-in/out on shared devices, native push and privacy behavior on actual hardware.
- Keep pilot orgs isolated from real operational production figures; don't use dummy production inventory as live figures.
- Run the tracked GitHub CI checks, migration smoke/RLS and business E2E; capture evidence of real-user acceptance separately.
- All critical workflows must pass, no unresolved critical security/stock/financial defects; get release owner sign-off before production promotion.

## Data privacy and safety

- Only authenticated active members can consent for **themselves**. Administrators may view participants but cannot consent for others or fabricate individual reports.
- Reports are visible only to the tester and their authorized tenant administrators. Anonymous requests are denied.
- Pilot reports belong to the member who submitted them and cannot be edited or overwritten by admins.
- Withdrawal removes participation **and all pilot feedback** but does not terminate their normal organization membership.
- No email or passwords are stored in these pilot tables; membership auth remains Supabase Auth.
- No fake passes or fabricated sign-offs: the pilot dashboard shows submitted evidence only.

**Deployment dependency:** migration `0044_customer_pilot_testing.sql` and Admin/mobile builds must be deployed to the **dedicated FactoryOS project** before opt-in becomes usable. Creating the source feature is not a substitute for sending actual invitations or having real users test.
