# Phase 19: authenticated customer-pilot API regression testing

The `supabase/tests/pilot_auth_e2e.sh` script tests actual local Supabase Auth accounts, password sessions and PostgREST API calls. It runs after the existing foundation and security E2E test fixtures. All identities are *local, synthetic CI accounts*, not production customers.

Coverage: consent is initially absent; authenticated employee enrolls themself; submits failed workflow feedback; organization administrator reads scoped reports; unauthorized cross-tenant reads, forged consent and forged feedback are denied; an independent second-tenant user enrolls and reports; withdrawal deletes pilot reports while leaving normal organization membership intact; reporting after withdrawal is denied.

The test makes no network calls to a production URL and has no actual customer credentials. Passing CI does not mean real customers or devices have been tested; migrations through 0045, SMTP, FCM, hosting and consenting client representatives are still required in the isolated FactoryOS production project.
