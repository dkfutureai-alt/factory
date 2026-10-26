# FactoryOS Mobile + Admin — Production pilot acceptance

This is a manual acceptance plan for the **dedicated FactoryOS project only**. It does not constitute test evidence, production approval, or permission to deploy into Janseva/Salon environments.

## Pilot prerequisites

- Record exact release commit, Android/iOS package identities, web URL, Supabase project ref and Firebase project ID.
- Keep separate Organization A and Organization B with two factories in Organization A.
- Create real, consented test accounts: Platform Owner, Organization Admin, Factory Manager (Plant A), Supervisor, Employee, Driver, Viewer. Use non-customer test data and authorized devices.
- Configure SMTP, FCM/APNs, private Storage policies and protected CI environments; confirm approved release secrets without logging values.

## Execute and record a pass/fail screenshot or API trace for each flow

| Area | Authorized end-to-end workflow | Negative / isolation check |
| --- | --- | --- |
| Invitations | Org admin sends invite; user opens allowlisted link, sets password and completes profile | Expired invitation reissue; wrong user/account cannot accept or access |
| Membership | Assign Plant A to employee, change role, deactivate user, sign out | Employee cannot see Plant B or Organization B; disabled sessions lose server access |
| HR | Assign shift, check in/out, request leave, approve and report | Employee cannot approve own leave or edit other people's attendance |
| Inventory | Scan QR/barcode, receive stock, transfer and issue material | Deny insufficient stock, other factory and unauthorised write |
| Production | Start batch, issue BOM materials, record output/scrap, complete | Prevent overproduction and unaccounted production output |
| Quality | Execute inspection, register NCR, quarantine and approve release | Employee cannot issue certificate or override manager approval |
| Purchase/Sales | Purchase request -> PO -> GRN -> invoice; quote -> order -> allocate -> invoice | Deny cross-factory orders and overpayment |
| Warehouse | Put away -> pick -> stage -> handoff -> cycle count | Deny cross-factory bin/storage access |
| Fleet/Delivery | Driver login -> assigned trip -> dispatch -> customer POD -> returnable collection | Different driver cannot access trip; POD private media scoped |
| Maintenance | Scan asset, raise work order, log spare/downtime, upload media | Unassigned employee cannot modify work order |
| Reports/Audit | Authorized KPIs and activity; reconcile transactions with ledger | Factory Manager cannot view unassigned-factory audit history |
| Notifications | Register device -> FCM push -> open guarded route -> sign out -> another user signs in | Old device token disabled; no cross-role unauthorized destination |

## Exit gates

1. GitHub CI is green on the exact final commit, including Flutter Application Quality, Mobile Release Quality, Supabase Foundation Checks, release-tool-tests and workflow lint.
2. Confirm Supabase migrations through 0043 and **no fictional production seeds**.
3. Run production smoke on the exact approved FactoryOS project, verify SMTP invite delivery, FCM/APNs and a physical Android/iOS device.
4. Record cloud backup/restore test, privacy/data-safety review, roll-back owner and customer-facing support contact.
5. Release owner signs off only after all critical workflows and denials pass; otherwise keep Issue #12 open.

**Automation limits:** GitHub's seeded authenticated E2E suite checks back-end permission and business logic, but it is not a substitute for real email delivery, OS push receipt, hardware scanning, signatures, POD media or physical-device pilot acceptance.
