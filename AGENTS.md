# FactoryOS instructions for coding agents

**Read [agent.md](./agent.md) before editing, testing or releasing FactoryOS.** It is the maintained project handoff: architecture, code layout, validated state, local tests, protected production workflows, real customer pilot requirements and remaining blockers.

All work must remain in `dkfutureai-alt/factory`. The actual repository and connected FactoryOS Supabase project are the source of truth; refresh their status before claiming any milestone. Do not touch Salon, Janseva or any other application, environment, credentials, Firebase or customer data.

Never treat a green local CI suite as production deployment, a real customer pilot, physical-device verification or a tested recovery. Do not run `supabase db reset --linked`, use ad-hoc migrations on production, commit customer database exports or expose service-role secrets. Use protected, independently reviewed FactoryOS release workflows with an exact project-ref confirmation. Do not invent user testing or production results.

Keep [agent.md](./agent.md), [the go-live checklist](./docs/PRODUCTION_GO_LIVE_CHECKLIST.md), and [issue #12](https://github.com/dkfutureai-alt/factory/issues/12) aligned with actual verified changes.