# Phase 9 — Vehicles, Drivers, Trips & Fuel

Status: **complete and CI validated**.

## Workflow

Phase 9 adds the operational fleet layer between Warehouse dispatch readiness and the later Dispatch & Delivery phase:

**Vehicle master → Driver master → Vehicle/driver assignment → Trip planning → Driver start → Fuel/odometer capture → Arrival → Completion → Service/compliance follow-up → Fleet reports**

Warehouse dispatch handoffs can be linked to a trip, while physical customer delivery, proof of delivery and returnables remain reserved for Phase 10.

## Backend

Migrations:

- `supabase/migrations/0016_fleet_operations.sql`
- `supabase/migrations/0017_fleet_scope_hardening.sql`
- `supabase/migrations/0018_fleet_integrity_hardening.sql`
- `supabase/migrations/0019_fleet_trigger_hardening.sql`

Operational tables:

- `fleet_vehicles`
- `fleet_drivers`
- `fleet_vehicle_driver_assignments`
- `fleet_trips`
- `fleet_odometer_logs`
- `fleet_fuel_entries`
- `fleet_service_reminders`

Each vehicle owns an Inventory `stock_locations` record with `location_type='vehicle'`, preserving a single location model for the later Dispatch stock-transfer workflow.

## Controls

- Tenant/factory RLS is mandatory across every Fleet table.
- Vehicle and driver masters are manager-controlled.
- Driver execution is limited to the signed-in driver's own active trip/vehicle context.
- Odometer readings cannot move backward.
- Expired driver licences block trip start.
- Warehouse handoffs cannot be attached to conflicting active trips.
- Driver fuel entries are limited to the driver's assigned vehicle/trip scope.
- Fuel history and odometer history are audit-oriented operational records.
- Organization-wide management reports remain restricted to authorized admin roles.
- Fleet organization/factory scope, vehicle Inventory-location links and driver employee links are immutable through the hardened shared trigger.

## Admin Web

`apps/admin_web/lib/fleet_management.dart`

Connected from the existing `vehicles` module and includes:

- Fleet dashboard KPIs;
- factory selector;
- vehicle master and status controls;
- driver master and vehicle/driver assignment;
- trip planning and cancellation;
- Warehouse handoff linkage;
- fuel ledger entry/history;
- service/compliance reminders;
- trip, fuel and service-due reports.

The screen follows the existing FactoryOS visual system: navy/blue hierarchy, compact operational cards, clear status chips, minimal text and responsive Admin navigation.

## Driver Mobile

`apps/mobile/lib/fleet_driver.dart`

The Driver role receives a dedicated Fleet workspace with:

- assigned vehicle summary;
- current odometer and vehicle documents;
- driving-licence status;
- assigned/active trip cards;
- Start Trip → Mark Arrived → Complete Trip workflow;
- odometer validation at every trip milestone;
- fuel entry with quantity, rate, total, odometer, vendor and receipt reference;
- recent fuel history;
- trip history.

Non-driver mobile roles are directed to the Admin fleet planning surface instead of receiving driver-only execution controls.

## Demo data

`supabase/seed_phase9.sql`

The fictional Aarohan demo includes vehicle locations, truck/tanker examples, fictional drivers, active assignments, planned/completed trips, odometer history, fuel history and service/compliance reminders. No real company/person data is used.

## Automated validation

Database schema/integrity smoke coverage:

- `supabase/tests/0016_fleet_smoke.sql`

Authenticated Fleet E2E:

- `supabase/tests/fleet_auth_e2e.sh`

Coverage includes manager planning permissions, Driver-role execution, factory isolation, odometer/fuel controls, service reminder lifecycle, cross-factory denial, report authorization and Fleet integrity hardening.

Flutter CI analyzes the shared core, Admin web including Fleet and Driver mobile including Fleet, and builds the Admin release web target.

Validated together on Phase 9 branch head `634fe97b2283d716146a52c20e5e7a6f7bdfe546`:

- Flutter Application Quality — pass;
- Supabase Foundation Checks — pass.

## Next

Phase 10 is **Dispatch, Delivery & Returnables**: consume Warehouse handoff + Fleet trip, perform ledger-backed staging/vehicle/customer movements, proof of delivery, empty-cylinder/returnable pickup, delivery exceptions and delivery reports.
