# FactoryOS — Environment Ownership and Deployment Evidence

| Environment | Purpose | Minimum guard | Current evidence state |
| --- | --- | --- | --- |
| GitHub source and isolated CI | Unit/SQL/JWT E2E and release workflow lint | Exact SHA, fictional seeds, scoped jobs | Source checks verified for audited main in [../status.md](../status.md) |
| Local development | Flutter/Admin/manual UI | Non-production credentials, disposable fixtures | No connected physical workstation asserted |
| FactoryOS staging/pilot | Rehearse actual Auth, schema, devices and customer flows | Independent tenant, legal consent, separate secrets | Not verified by this documentation task |
| Dedicated FactoryOS production | Real tenant data and apps | Owner approval, controlled migrations, backup/restore, RLS, smoke, support | **Not declared deployed**; verify live backend before changes |
| Salon/Janseva/other projects | **Outside scope** | **Do not access or reuse** | No modification permitted |

Known FactoryOS production project reference recorded in [../agent.md](../agent.md) is `zevrmvhnibztbxizswgu`. An identifier is **not** proof of permission or deployment.

For any deployment record:
**Target/ref/region, owner approval URL, exact Git SHA, migration numbers, command/workflow, verification, rollback/recovery plan, release artifacts, signed build IDs, tester sign-off, date/time.** Never publish credentials.
