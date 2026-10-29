# FactoryOS — Architecture and Product Decision Register

A **decision register** records why something was accepted, deferred or rejected. This file is a living history, not an excuse to replace source-of-truth code or release runbooks.

| ADR | Date | Decision / constraint | Reason and evidence | Revisit when |
| --- | --- | --- | --- | --- |
| ADR-001 | 2026-10-29 documented | FactoryOS only uses distinct factory-specific Supabase/Firebase/hosting | Prevent Salon/Janseva cross-project data risk; [../agent.md](../agent.md) | Change of owner-approved infrastructure |
| ADR-002 | 2026-10-29 documented | Source CI, live deployment, device QA, pilot sign-off have separate states | Guard false go-live claims; [../status.md](../status.md) | Never collapse without evidence |
| ADR-003 | 2026-10-29 documented | Current mobile multi-active-membership state fails closed | All mobile RPC/route/cache scopes not yet accepted; issues #45/#47 | Fully verified selection design |
| ADR-004 | 2026-10-29 documented | Quantities from Inventory ledger; returnables staged before inspected warehouse receipt | Prevent phantom stock and unsafe quarantine bypass | New transactional domain workflow |
| ADR-005 | 2026-10-29 documented | Cylinder registry/attestations are not physical custody certification | Migrations 0047–0052 source protections; issue #27 open | Mandatory physical and safety acceptance |
| ADR-006 | 2026-10-29 proposed UX | Shared Material 3 tokens and calm reduced-motion microinteractions | Align screen styles and factory usability | Visual research and hardware testing |
| ADR-007 | 2026-10-29 process | Change via PR exact-head review; live schema via protected owner-reviewed plan/release | Required change audit and safe recovery | Formal process revision |

### New decision template
**ID / date / owner / scope / problem / considered alternatives / chosen decision / technical and user impacts / risks / security review / source links / acceptance tests / superseded-by.** Never mark a **proposed** UI concept as shipped or replace a historical decision without a supersession entry.
