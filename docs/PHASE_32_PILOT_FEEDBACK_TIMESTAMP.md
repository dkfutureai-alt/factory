# Phase 32 — protect real-customer pilot report chronology

**Scope:** server-owned timestamp on `public.pilot_feedback`; still **not**
independent proof that a real tester completed a factory workflow.

## Problem

FactoryOS already enforced database-stamped `pilot_participants.consented_at`,
but its `pilot_feedback.created_at` was only given a default of `now()`.
An authenticated consented participant could override that default by inserting
an explicit date through the Supabase Data API. The protected read-only
`FactoryOS Real Customer Pilot Acceptance` verifier relies on the latest
report per scenario and a 14-day recency window. Forged timestamps would make
that recency test unreliable.

## Fix

Migration `0051_pilot_feedback_server_timestamp.sql` installs a
`BEFORE INSERT` trigger that overwrites **every** client-provided report
timestamp with the database server's `now()`. It uses an invoker-rights,
fixed-search-path trigger function and does **not** grant additional
table permissions or modify tenant RLS. Existing reports are **not**
retimestamped. Each report still belongs to its consented, signed-in
participant and remains append-only to authenticated clients.

The rollback-only SQL test uses an isolated synthetic Auth member and
explicitly inserts fake year-2099 and year-2000 dates, plus a default date.
It requires all three to be server-stamped while preserving their actual
`passed`, `failed` and `blocked` result fields. It also checks the
trigger, anon denial and authenticated UPDATE/DELETE privileges. Existing
`0044` consent and JWT pilot E2E tests continue to run.

## What this does NOT prove

A participant can still *self-report* Passed without actually completing a
workflow. The 14-scenario acceptance script checks report age and
cross-tenant authorization; a real release requires witnessed physical
staff/device operations, correct inventory and financial balances, actual
FCM/SMTP delivery, storage recovery and release-owner sign-off. Fake
historical data must never be created to satisfy live acceptance.

**Deployment:** committing migration 0051 does not alter the dedicated
FactoryOS production project. Production is controlled by the separate
approved read-only plan, exact-head CI, encrypted backup/restore and protected
owner-reviewed database-only release.
