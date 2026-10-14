# Notification Security Test Plan

Target: exercise recipient isolation, critical preferences, and the mark-read RPC in PostgreSQL CI. This plan is repository-only and does not change Supabase deployment.

Verification gates: schema and seeds apply; authenticated users cannot see others' recipients or tokens; suspended users cannot read alerts; the read-state RPC updates only the caller's recipient; service-only tables remain inaccessible.
