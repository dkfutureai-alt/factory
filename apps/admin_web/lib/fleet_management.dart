import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FleetManagementPage extends StatefulWidget {
  const FleetManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<FleetManagementPage> createState() => _FleetManagementPageState();
}

class _FleetManagementPageState extends State<FleetManagementPage> {
  String? factoryId;
  int section = 0;
  Future<FleetSnapshot>? future;

  FleetRepository get repository => FleetRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (widget.factories.isEmpty) return;
    var selected = widget.factories.first['id'] as String;
    if (widget.actorRole == AppRole.factoryManager) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final rows = await Supabase.instance.client
            .from('factory_members')
            .select('factory_id')
            .eq('organization_id', widget.organizationId)
            .eq('user_id', userId)
            .eq('is_active', true);
        final allowed = rows.map((row) => row['factory_id'] as String).toSet();
        final match = widget.factories.where((factory) => allowed.contains(factory['id'])).firstOrNull;
        if (match != null) selected = match['id'] as String;
      }
    }
    if (!mounted) return;
    setState(() {
      factoryId = selected;
      future = repository.load(widget.organizationId, selected);
    });
  }

  void reload() {
    final id = factoryId;
    if (id == null) return;
    setState(() => future = repository.load(widget.organizationId, id));
  }

  void chooseFactory(String? value) {
    if (value == null || value == factoryId) return;
    setState(() {
      factoryId = value;
      future = repository.load(widget.organizationId, value);
    });
  }

  void message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      message(success);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addVehicle() async {
    final id = factoryId;
    if (id == null) return;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const VehicleEditor(),
    );
    if (draft == null) return;
    await run(() => repository.createVehicle(id, draft), 'Vehicle created with Inventory vehicle location.');
  }

  Future<void> addDriver(FleetSnapshot data) async {
    final id = factoryId;
    if (id == null) return;
    final existing = data.drivers.map((row) => row['employee_id']).toSet();
    final employees = data.employees.where((row) => !existing.contains(row['id'])).toList();
    if (employees.isEmpty) return message('No active employee is available to create as a driver.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DriverEditor(employees: employees),
    );
    if (draft == null) return;
    await run(() => repository.createDriver(id, draft), 'Driver created.');
  }

  Future<void> assignDriver(FleetSnapshot data) async {
    final vehicles = data.vehicles.where((row) => row['status'] == 'active').toList();
    final drivers = data.drivers.where((row) => row['status'] == 'active').toList();
    if (vehicles.isEmpty || drivers.isEmpty) return message('Create an active vehicle and driver first.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AssignmentEditor(vehicles: vehicles, drivers: drivers),
    );
    if (draft == null) return;
    await run(() => repository.assignDriver(draft), 'Vehicle and driver assignment updated.');
  }

  Future<void> addTrip(FleetSnapshot data) async {
    final id = factoryId;
    if (id == null) return;
    final assignments = data.assignments.where((row) => row['ended_at'] == null).toList();
    if (assignments.isEmpty) return message('Create an active vehicle-driver assignment first.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TripEditor(
        assignments: assignments,
        vehicles: data.vehicles,
        drivers: data.drivers,
        handoffs: data.handoffs,
      ),
    );
    if (draft == null) return;
    await run(() => repository.createTrip(id, draft), 'Trip assigned.');
  }

  Future<void> addFuel(FleetSnapshot data) async {
    final vehicles = data.vehicles.where((row) => row['status'] == 'active' && row['fuel_type'] != 'electric').toList();
    if (vehicles.isEmpty) return message('No active liquid-fuel vehicle is available.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => FuelEditor(vehicles: vehicles, drivers: data.drivers, trips: data.trips),
    );
    if (draft == null) return;
    await run(() => repository.recordFuel(draft), 'Fuel entry recorded.');
  }

  Future<void> addReminder(FleetSnapshot data) async {
    final vehicles = data.vehicles.where((row) => row['status'] != 'inactive').toList();
    if (vehicles.isEmpty) return message('No fleet vehicle is available.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ServiceEditor(vehicles: vehicles),
    );
    if (draft == null) return;
    await run(() => repository.createServiceReminder(draft), 'Service reminder created.');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.factories.isEmpty) {
      return const Center(child: Text('Create a factory before configuring Fleet.'));
    }
    final currentFuture = future;
    if (currentFuture == null) return const Center(child: CircularProgressIndicator());

    return FutureBuilder<FleetSnapshot>(
      future: currentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _FleetError(message: '${snapshot.error}', onRetry: reload);
        final data = snapshot.requireData;
        final tabs = <_FleetSection>[
          _FleetSection('Dashboard', Icons.local_shipping_outlined, FleetDashboard(data: data)),
          _FleetSection('Vehicles', Icons.fire_truck_outlined, VehiclesSection(data: data, onAdd: addVehicle, onStatus: (row, status) => run(() => repository.updateVehicleStatus(row['id'] as String, status), 'Vehicle status updated.'))),
          _FleetSection('Drivers', Icons.badge_outlined, DriversSection(data: data, onAdd: () => addDriver(data), onAssign: () => assignDriver(data))),
          _FleetSection('Trips', Icons.route_outlined, TripsSection(data: data, onAdd: () => addTrip(data), onCancel: (row) => run(() => repository.cancelTrip(row['id'] as String), 'Trip cancelled.'))),
          _FleetSection('Fuel', Icons.local_gas_station_outlined, FuelSection(data: data, onAdd: () => addFuel(data))),
          _FleetSection('Service', Icons.build_circle_outlined, ServiceSection(data: data, onAdd: () => addReminder(data), onComplete: (row) => run(() => repository.completeServiceReminder(row['id'] as String), 'Service reminder completed.'))),
          _FleetSection('Reports', Icons.analytics_outlined, FleetReports(data: data)),
        ];
        if (section >= tabs.length) section = 0;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, FactorySpacing.lg, FactorySpacing.lg, 0),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: FactoryColors.blue),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(child: Text('Fleet Management', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      value: factoryId,
                      decoration: const InputDecoration(labelText: 'Factory', isDense: true),
                      items: widget.factories.map((factory) => DropdownMenuItem<String>(value: factory['id'] as String, child: Text(factory['name'] as String, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: chooseFactory,
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.lg, vertical: FactorySpacing.sm),
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.xs),
                itemBuilder: (_, i) => ChoiceChip(
                  selected: section == i,
                  avatar: Icon(tabs[i].icon, size: 18),
                  label: Text(tabs[i].label),
                  onSelected: (_) => setState(() => section = i),
                ),
              ),
            ),
            Expanded(child: tabs[section].page),
          ],
        );
      },
    );
  }
}

class FleetSnapshot {
  const FleetSnapshot({
    required this.summary,
    required this.vehicles,
    required this.drivers,
    required this.assignments,
    required this.trips,
    required this.fuel,
    required this.services,
    required this.employees,
    required this.handoffs,
    required this.tripReport,
    required this.fuelReport,
    required this.serviceReport,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> fuel;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> handoffs;
  final List<Map<String, dynamic>> tripReport;
  final List<Map<String, dynamic>> fuelReport;
  final List<Map<String, dynamic>> serviceReport;
}

class FleetRepository {
  FleetRepository(this.client);
  final SupabaseClient client;

  Future<FleetSnapshot> load(String orgId, String factoryId) async {
    final values = await Future.wait<dynamic>([
      client.rpc('fleet_dashboard_summary', params: {'p_organization_id': orgId, 'p_factory_id': factoryId}),
      client.from('fleet_vehicles').select('id,factory_id,stock_location_id,vehicle_code,registration_no,vehicle_type,make,model,fuel_type,capacity_quantity,capacity_unit,current_odometer_km,insurance_expiry,fitness_expiry,permit_expiry,puc_expiry,status,notes').eq('organization_id', orgId).eq('factory_id', factoryId).order('vehicle_code'),
      client.from('fleet_drivers').select('id,factory_id,employee_id,license_no,license_type,license_expiry,emergency_phone,status,notes,employees(full_name,employee_code,phone,email)').eq('organization_id', orgId).eq('factory_id', factoryId).order('created_at', ascending: false),
      client.from('fleet_vehicle_driver_assignments').select('id,factory_id,vehicle_id,driver_id,effective_from,ended_at,notes').eq('organization_id', orgId).eq('factory_id', factoryId).order('effective_from', ascending: false).limit(200),
      client.from('fleet_trips').select('id,factory_id,trip_no,vehicle_id,driver_id,sales_order_id,warehouse_handoff_id,origin,destination,status,planned_start_at,planned_end_at,started_at,arrived_at,completed_at,start_odometer_km,arrival_odometer_km,end_odometer_km,cancellation_reason,notes,fleet_vehicles(vehicle_code,registration_no),fleet_drivers(employees(full_name))').eq('organization_id', orgId).eq('factory_id', factoryId).order('planned_start_at', ascending: false).limit(250),
      client.from('fleet_fuel_entries').select('id,factory_id,vehicle_id,driver_id,trip_id,fuel_type,quantity_liters,price_per_liter,total_amount,odometer_km,filled_at,vendor,receipt_reference,notes,fleet_vehicles(vehicle_code,registration_no)').eq('organization_id', orgId).eq('factory_id', factoryId).order('filled_at', ascending: false).limit(250),
      client.from('fleet_service_reminders').select('id,factory_id,vehicle_id,reminder_type,title,due_date,due_odometer_km,status,completed_at,completed_odometer_km,notes,fleet_vehicles(vehicle_code,registration_no,current_odometer_km)').eq('organization_id', orgId).eq('factory_id', factoryId).order('created_at', ascending: false).limit(250),
      client.from('employees').select('id,employee_code,full_name,email,phone,primary_factory_id,status').eq('organization_id', orgId).eq('primary_factory_id', factoryId).eq('status', 'active').order('full_name'),
      client.from('warehouse_dispatch_handoffs').select('id,handoff_no,sales_order_id,status,created_at').eq('organization_id', orgId).eq('factory_id', factoryId).eq('status', 'handed_off').order('created_at', ascending: false).limit(100),
      client.rpc('fleet_trip_report', params: {'p_organization_id': orgId, 'p_factory_id': factoryId, 'p_limit': 250}),
      client.rpc('fleet_fuel_report', params: {'p_organization_id': orgId, 'p_factory_id': factoryId, 'p_limit': 250}),
      client.rpc('fleet_service_due_report', params: {'p_organization_id': orgId, 'p_factory_id': factoryId, 'p_limit': 250}),
    ]);
    return FleetSnapshot(
      summary: Map<String, dynamic>.from(values[0] as Map),
      vehicles: _rows(values[1]),
      drivers: _rows(values[2]),
      assignments: _rows(values[3]),
      trips: _rows(values[4]),
      fuel: _rows(values[5]),
      services: _rows(values[6]),
      employees: _rows(values[7]),
      handoffs: _rows(values[8]),
      tripReport: _rows(values[9]),
      fuelReport: _rows(values[10]),
      serviceReport: _rows(values[11]),
    );
  }

  Future<void> createVehicle(String factoryId, Map<String, dynamic> d) async => client.rpc('fleet_create_vehicle', params: {
        'p_factory_id': factoryId,
        'p_vehicle_code': d['vehicle_code'],
        'p_registration_no': d['registration_no'],
        'p_vehicle_type': d['vehicle_type'],
        'p_make': d['make'],
        'p_model': d['model'],
        'p_fuel_type': d['fuel_type'],
        'p_capacity_quantity': d['capacity_quantity'],
        'p_capacity_unit': d['capacity_unit'],
        'p_current_odometer_km': d['current_odometer_km'],
        'p_notes': d['notes'],
      });

  Future<void> updateVehicleStatus(String id, String status) async => client.from('fleet_vehicles').update({'status': status}).eq('id', id);

  Future<void> createDriver(String factoryId, Map<String, dynamic> d) async => client.rpc('fleet_create_driver', params: {
        'p_factory_id': factoryId,
        'p_employee_id': d['employee_id'],
        'p_license_no': d['license_no'],
        'p_license_type': d['license_type'],
        'p_license_expiry': d['license_expiry'],
        'p_emergency_phone': d['emergency_phone'],
        'p_notes': d['notes'],
      });

  Future<void> assignDriver(Map<String, dynamic> d) async => client.rpc('fleet_assign_driver', params: {
        'p_vehicle_id': d['vehicle_id'],
        'p_driver_id': d['driver_id'],
        'p_notes': d['notes'],
      });

  Future<void> createTrip(String factoryId, Map<String, dynamic> d) async => client.rpc('fleet_create_trip', params: {
        'p_factory_id': factoryId,
        'p_vehicle_id': d['vehicle_id'],
        'p_driver_id': d['driver_id'],
        'p_origin': d['origin'],
        'p_destination': d['destination'],
        'p_planned_start_at': d['planned_start_at'],
        'p_planned_end_at': d['planned_end_at'],
        'p_sales_order_id': null,
        'p_warehouse_handoff_id': d['warehouse_handoff_id'],
        'p_notes': d['notes'],
      });

  Future<void> cancelTrip(String id) async => client.rpc('fleet_cancel_trip', params: {'p_trip_id': id, 'p_reason': 'Cancelled from Fleet admin'});

  Future<void> recordFuel(Map<String, dynamic> d) async => client.rpc('fleet_record_fuel', params: {
        'p_vehicle_id': d['vehicle_id'],
        'p_driver_id': d['driver_id'],
        'p_trip_id': d['trip_id'],
        'p_quantity_liters': d['quantity_liters'],
        'p_price_per_liter': d['price_per_liter'],
        'p_odometer_km': d['odometer_km'],
        'p_vendor': d['vendor'],
        'p_receipt_reference': d['receipt_reference'],
        'p_notes': d['notes'],
      });

  Future<void> createServiceReminder(Map<String, dynamic> d) async => client.rpc('fleet_create_service_reminder', params: {
        'p_vehicle_id': d['vehicle_id'],
        'p_reminder_type': d['reminder_type'],
        'p_title': d['title'],
        'p_due_date': d['due_date'],
        'p_due_odometer_km': d['due_odometer_km'],
        'p_notes': d['notes'],
      });

  Future<void> completeServiceReminder(String id) async => client.rpc('fleet_complete_service_reminder', params: {'p_reminder_id': id});
}

class FleetDashboard extends StatelessWidget {
  const FleetDashboard({required this.data, super.key});
  final FleetSnapshot data;

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final activeTrips = data.trips.where((row) => const {'assigned', 'started', 'arrived', 'planned'}.contains(row['status'])).take(8).toList();
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [
          _FleetMetric('Active vehicles', '${s['active_vehicles'] ?? 0}', Icons.fire_truck_outlined, FactoryColors.blue),
          _FleetMetric('Open trips', '${s['open_trips'] ?? 0}', Icons.route_outlined, FactoryColors.success),
          _FleetMetric('Active drivers', '${s['active_drivers'] ?? 0}', Icons.badge_outlined, FactoryColors.navy),
          _FleetMetric('Service overdue', '${s['overdue_service'] ?? 0}', Icons.build_circle_outlined, FactoryColors.danger),
          _FleetMetric('Fuel cost · 30d', '₹${_money(s['fuel_cost_30d'])}', Icons.local_gas_station_outlined, FactoryColors.warning),
          _FleetMetric('Docs expiring · 30d', '${s['expiring_documents_30d'] ?? 0}', Icons.description_outlined, FactoryColors.warning),
        ]),
        const SizedBox(height: FactorySpacing.lg),
        Text('Live trip board', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.sm),
        if (activeTrips.isEmpty) const _EmptyCard('No active trips for this factory.'),
        for (final trip in activeTrips) _TripCard(trip: trip),
      ],
    );
  }
}

class VehiclesSection extends StatelessWidget {
  const VehiclesSection({required this.data, required this.onAdd, required this.onStatus, super.key});
  final FleetSnapshot data;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>, String) onStatus;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _SectionHeader(title: 'Vehicles', subtitle: 'Vehicle master, odometer and compliance status', actionLabel: 'Add vehicle', actionIcon: Icons.add, onAction: onAdd),
          const SizedBox(height: FactorySpacing.md),
          if (data.vehicles.isEmpty) const _EmptyCard('No vehicles have been created.'),
          for (final row in data.vehicles)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(_vehicleIcon(row['vehicle_type'] as String?))),
                title: Text('${row['vehicle_code']} · ${row['registration_no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text([
                  [row['make'], row['model']].whereType<String>().join(' '),
                  '${_number(row['current_odometer_km'])} km',
                  '${row['fuel_type']}',
                ].where((value) => value.isNotEmpty).join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => onStatus(row, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'active', child: Text('Set active')),
                    PopupMenuItem(value: 'maintenance', child: Text('Set maintenance')),
                    PopupMenuItem(value: 'out_of_service', child: Text('Set out of service')),
                    PopupMenuItem(value: 'inactive', child: Text('Set inactive')),
                  ],
                  child: _StatusChip('${row['status']}'),
                ),
              ),
            ),
        ],
      );
}

class DriversSection extends StatelessWidget {
  const DriversSection({required this.data, required this.onAdd, required this.onAssign, super.key});
  final FleetSnapshot data;
  final VoidCallback onAdd;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _SectionHeader(title: 'Drivers', subtitle: 'Licensed drivers and active vehicle assignments', actionLabel: 'Add driver', actionIcon: Icons.person_add_alt_1, onAction: onAdd, secondaryLabel: 'Assign', secondaryAction: onAssign),
          const SizedBox(height: FactorySpacing.md),
          if (data.drivers.isEmpty) const _EmptyCard('No fleet drivers have been created.'),
          for (final row in data.drivers)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(_driverName(row), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${row['license_type']} · ${row['license_no']} · expires ${_date(row['license_expiry'])}'),
                trailing: _StatusChip('${row['status']}'),
              ),
            ),
          const SizedBox(height: FactorySpacing.lg),
          Text('Assignment history', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          for (final row in data.assignments.take(100))
            Card(
              child: ListTile(
                leading: Icon(row['ended_at'] == null ? Icons.link : Icons.link_off),
                title: Text('${_vehicleLabel(data, row['vehicle_id'])} → ${_driverLabel(data, row['driver_id'])}'),
                subtitle: Text(row['ended_at'] == null ? 'Active since ${_dateTime(row['effective_from'])}' : 'Ended ${_dateTime(row['ended_at'])}'),
              ),
            ),
        ],
      );
}

class TripsSection extends StatelessWidget {
  const TripsSection({required this.data, required this.onAdd, required this.onCancel, super.key});
  final FleetSnapshot data;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onCancel;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _SectionHeader(title: 'Trips', subtitle: 'Plan route, assign driver and track lifecycle', actionLabel: 'New trip', actionIcon: Icons.add_road, onAction: onAdd),
          const SizedBox(height: FactorySpacing.md),
          if (data.trips.isEmpty) const _EmptyCard('No trips have been planned.'),
          for (final row in data.trips)
            _TripCard(
              trip: row,
              trailing: const {'planned', 'assigned'}.contains(row['status'])
                  ? IconButton(tooltip: 'Cancel trip', onPressed: () => onCancel(row), icon: const Icon(Icons.cancel_outlined))
                  : null,
            ),
        ],
      );
}

class FuelSection extends StatelessWidget {
  const FuelSection({required this.data, required this.onAdd, super.key});
  final FleetSnapshot data;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _SectionHeader(title: 'Fuel', subtitle: 'Immutable fuel ledger with odometer capture', actionLabel: 'Add fuel', actionIcon: Icons.local_gas_station_outlined, onAction: onAdd),
          const SizedBox(height: FactorySpacing.md),
          if (data.fuel.isEmpty) const _EmptyCard('No fuel entries have been recorded.'),
          for (final row in data.fuel)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.local_gas_station_outlined)),
                title: Text('${_nested(row, 'fleet_vehicles', 'vehicle_code') ?? 'Vehicle'} · ${_number(row['quantity_liters'])} L', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_dateTime(row['filled_at'])} · ${_number(row['odometer_km'])} km${row['vendor'] == null ? '' : ' · ${row['vendor']}'}'),
                trailing: Text('₹${_money(row['total_amount'])}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      );
}

class ServiceSection extends StatelessWidget {
  const ServiceSection({required this.data, required this.onAdd, required this.onComplete, super.key});
  final FleetSnapshot data;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onComplete;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _SectionHeader(title: 'Service & compliance', subtitle: 'Preventive service and vehicle document reminders', actionLabel: 'Add reminder', actionIcon: Icons.add_alert_outlined, onAction: onAdd),
          const SizedBox(height: FactorySpacing.md),
          if (data.services.isEmpty) const _EmptyCard('No service reminders exist.'),
          for (final row in data.services)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.build_outlined)),
                title: Text(row['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_nested(row, 'fleet_vehicles', 'vehicle_code') ?? ''} · ${row['reminder_type']} · ${row['due_date'] == null ? 'at ${_number(row['due_odometer_km'])} km' : 'due ${_date(row['due_date'])}'}'),
                trailing: row['status'] == 'open'
                    ? FilledButton.tonal(onPressed: () => onComplete(row), child: const Text('Complete'))
                    : _StatusChip('${row['status']}'),
              ),
            ),
        ],
      );
}

class FleetReports extends StatelessWidget {
  const FleetReports({required this.data, super.key});
  final FleetSnapshot data;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Text('Fleet reports', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: FactorySpacing.lg),
          Text('Service due', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          if (data.serviceReport.isEmpty) const _EmptyCard('No open service items.'),
          for (final row in data.serviceReport.take(50))
            Card(child: ListTile(leading: Icon(_dueIcon('${row['due_state']}')), title: Text('${row['vehicle_code']} · ${row['title']}'), subtitle: Text('${row['reminder_type']} · ${row['due_state']}'), trailing: Text(row['due_date'] == null ? '${_number(row['due_odometer_km'])} km' : _date(row['due_date'])))),
          const SizedBox(height: FactorySpacing.lg),
          Text('Recent trips', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          _ReportTable(
            columns: const ['Trip', 'Vehicle', 'Driver', 'Status', 'Route', 'Distance'],
            rows: data.tripReport.take(100).map((row) => [
              '${row['trip_no']}',
              '${row['vehicle_code']}',
              '${row['driver_name']}',
              '${row['status']}',
              '${row['origin']} → ${row['destination']}',
              row['distance_km'] == null ? '—' : '${_number(row['distance_km'])} km',
            ]).toList(),
          ),
          const SizedBox(height: FactorySpacing.lg),
          Text('Fuel ledger', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          _ReportTable(
            columns: const ['Date', 'Vehicle', 'Driver', 'Litres', 'Rate', 'Total'],
            rows: data.fuelReport.take(100).map((row) => [
              _dateTime(row['filled_at']),
              '${row['vehicle_code']}',
              '${row['driver_name'] ?? '—'}',
              _number(row['quantity_liters']),
              '₹${_money(row['price_per_liter'])}',
              '₹${_money(row['total_amount'])}',
            ]).toList(),
          ),
        ],
      );
}

class VehicleEditor extends StatefulWidget {
  const VehicleEditor({super.key});
  @override
  State<VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<VehicleEditor> {
  final code = TextEditingController();
  final registration = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  final capacity = TextEditingController();
  final capacityUnit = TextEditingController();
  final odometer = TextEditingController(text: '0');
  final notes = TextEditingController();
  String type = 'truck';
  String fuel = 'diesel';

  @override
  void dispose() {
    for (final controller in [code, registration, make, model, capacity, capacityUnit, odometer, notes]) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add vehicle'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(code, 'Vehicle code'),
          _field(registration, 'Registration number'),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Vehicle type'), items: const ['truck', 'tanker', 'van', 'pickup', 'forklift', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => type = value ?? type)),
          const SizedBox(height: FactorySpacing.sm),
          _field(make, 'Make'),
          _field(model, 'Model'),
          DropdownButtonFormField<String>(value: fuel, decoration: const InputDecoration(labelText: 'Fuel type'), items: const ['diesel', 'petrol', 'cng', 'electric', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => fuel = value ?? fuel)),
          const SizedBox(height: FactorySpacing.sm),
          _field(capacity, 'Capacity quantity', numeric: true),
          _field(capacityUnit, 'Capacity unit'),
          _field(odometer, 'Current odometer (km)', numeric: true),
          _field(notes, 'Notes'),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          if (code.text.trim().length < 2 || registration.text.trim().length < 3) return;
          Navigator.pop(context, {
            'vehicle_code': code.text.trim().toUpperCase(),
            'registration_no': registration.text.trim().toUpperCase(),
            'vehicle_type': type,
            'make': _blank(make.text),
            'model': _blank(model.text),
            'fuel_type': fuel,
            'capacity_quantity': double.tryParse(capacity.text.trim()),
            'capacity_unit': _blank(capacityUnit.text),
            'current_odometer_km': double.tryParse(odometer.text.trim()) ?? 0,
            'notes': _blank(notes.text),
          });
        }, child: const Text('Create'))],
      );
}

class DriverEditor extends StatefulWidget {
  const DriverEditor({required this.employees, super.key});
  final List<Map<String, dynamic>> employees;
  @override
  State<DriverEditor> createState() => _DriverEditorState();
}

class _DriverEditorState extends State<DriverEditor> {
  String? employeeId;
  final license = TextEditingController();
  final type = TextEditingController(text: 'HMV');
  final expiry = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();

  @override
  void dispose() {
    for (final controller in [license, type, expiry, phone, notes]) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add driver'),
        content: SizedBox(width: 540, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: employeeId, decoration: const InputDecoration(labelText: 'Employee'), items: widget.employees.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))).toList(), onChanged: (value) => setState(() => employeeId = value)),
          const SizedBox(height: FactorySpacing.sm),
          _field(license, 'Driving licence number'),
          _field(type, 'Licence type'),
          _field(expiry, 'Licence expiry (YYYY-MM-DD)'),
          _field(phone, 'Emergency phone'),
          _field(notes, 'Notes'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          if (employeeId == null || license.text.trim().length < 3 || type.text.trim().isEmpty || DateTime.tryParse(expiry.text.trim()) == null) return;
          Navigator.pop(context, {'employee_id': employeeId, 'license_no': license.text.trim(), 'license_type': type.text.trim(), 'license_expiry': expiry.text.trim(), 'emergency_phone': _blank(phone.text), 'notes': _blank(notes.text)});
        }, child: const Text('Create'))],
      );
}

class AssignmentEditor extends StatefulWidget {
  const AssignmentEditor({required this.vehicles, required this.drivers, super.key});
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> drivers;
  @override
  State<AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends State<AssignmentEditor> {
  String? vehicleId;
  String? driverId;
  final notes = TextEditingController();
  @override
  void dispose() { notes.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign driver to vehicle'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: vehicleId, decoration: const InputDecoration(labelText: 'Vehicle'), items: widget.vehicles.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['vehicle_code']} · ${row['registration_no']}'))).toList(), onChanged: (value) => setState(() => vehicleId = value)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: driverId, decoration: const InputDecoration(labelText: 'Driver'), items: widget.drivers.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text(_driverName(row)))).toList(), onChanged: (value) => setState(() => driverId = value)),
          const SizedBox(height: FactorySpacing.sm),
          _field(notes, 'Notes'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (vehicleId != null && driverId != null) Navigator.pop(context, {'vehicle_id': vehicleId, 'driver_id': driverId, 'notes': _blank(notes.text)}); }, child: const Text('Assign'))],
      );
}

class TripEditor extends StatefulWidget {
  const TripEditor({required this.assignments, required this.vehicles, required this.drivers, required this.handoffs, super.key});
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> handoffs;
  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  String? assignmentId;
  String? handoffId;
  final origin = TextEditingController();
  final destination = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();
  final notes = TextEditingController();

  @override
  void dispose() { for (final c in [origin, destination, start, end, notes]) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New trip'),
        content: SizedBox(width: 600, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: assignmentId, decoration: const InputDecoration(labelText: 'Vehicle + driver'), items: widget.assignments.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${_labelById(widget.vehicles, row['vehicle_id'], 'vehicle_code')} · ${_labelByDriver(widget.drivers, row['driver_id'])}'))).toList(), onChanged: (value) => setState(() => assignmentId = value)),
          const SizedBox(height: FactorySpacing.sm),
          _field(origin, 'Origin'),
          _field(destination, 'Destination'),
          _field(start, 'Planned start (YYYY-MM-DD HH:MM)'),
          _field(end, 'Planned end (optional)'),
          DropdownButtonFormField<String?>(value: handoffId, decoration: const InputDecoration(labelText: 'Warehouse handoff (optional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...widget.handoffs.map((row) => DropdownMenuItem<String?>(value: row['id'] as String, child: Text('${row['handoff_no']}')))], onChanged: (value) => setState(() => handoffId = value)),
          const SizedBox(height: FactorySpacing.sm),
          _field(notes, 'Notes'),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final assignment = widget.assignments.where((row) => row['id'] == assignmentId).firstOrNull;
          final startAt = _parseLocalDateTime(start.text);
          final endAt = _parseLocalDateTime(end.text);
          if (assignment == null || origin.text.trim().length < 2 || destination.text.trim().length < 2 || startAt == null) return;
          Navigator.pop(context, {'vehicle_id': assignment['vehicle_id'], 'driver_id': assignment['driver_id'], 'origin': origin.text.trim(), 'destination': destination.text.trim(), 'planned_start_at': startAt.toIso8601String(), 'planned_end_at': endAt?.toIso8601String(), 'warehouse_handoff_id': handoffId, 'notes': _blank(notes.text)});
        }, child: const Text('Assign trip'))],
      );
}

class FuelEditor extends StatefulWidget {
  const FuelEditor({required this.vehicles, required this.drivers, required this.trips, super.key});
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> trips;
  @override
  State<FuelEditor> createState() => _FuelEditorState();
}

class _FuelEditorState extends State<FuelEditor> {
  String? vehicleId;
  String? driverId;
  String? tripId;
  final quantity = TextEditingController();
  final rate = TextEditingController();
  final odometer = TextEditingController();
  final vendor = TextEditingController();
  final receipt = TextEditingController();
  final notes = TextEditingController();
  @override
  void dispose() { for (final c in [quantity, rate, odometer, vendor, receipt, notes]) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final trips = widget.trips.where((row) => vehicleId == null || row['vehicle_id'] == vehicleId).toList();
    return AlertDialog(
      title: const Text('Add fuel entry'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: vehicleId, decoration: const InputDecoration(labelText: 'Vehicle'), items: widget.vehicles.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['vehicle_code']} · ${row['registration_no']}'))).toList(), onChanged: (value) => setState(() { vehicleId = value; tripId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String?>(value: driverId, decoration: const InputDecoration(labelText: 'Driver (optional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...widget.drivers.map((row) => DropdownMenuItem<String?>(value: row['id'] as String, child: Text(_driverName(row))))], onChanged: (value) => setState(() => driverId = value)),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String?>(value: tripId, decoration: const InputDecoration(labelText: 'Trip (optional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...trips.map((row) => DropdownMenuItem<String?>(value: row['id'] as String, child: Text('${row['trip_no']} · ${row['destination']}')))], onChanged: (value) => setState(() => tripId = value)),
        const SizedBox(height: FactorySpacing.sm),
        _field(quantity, 'Quantity (litres)', numeric: true),
        _field(rate, 'Rate per litre', numeric: true),
        _field(odometer, 'Odometer (km)', numeric: true),
        _field(vendor, 'Fuel station / vendor'),
        _field(receipt, 'Receipt reference'),
        _field(notes, 'Notes'),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
        final q = double.tryParse(quantity.text.trim());
        final r = double.tryParse(rate.text.trim());
        final o = double.tryParse(odometer.text.trim());
        if (vehicleId == null || q == null || q <= 0 || r == null || r < 0 || o == null) return;
        Navigator.pop(context, {'vehicle_id': vehicleId, 'driver_id': driverId, 'trip_id': tripId, 'quantity_liters': q, 'price_per_liter': r, 'odometer_km': o, 'vendor': _blank(vendor.text), 'receipt_reference': _blank(receipt.text), 'notes': _blank(notes.text)});
      }, child: const Text('Save'))],
    );
  }
}

class ServiceEditor extends StatefulWidget {
  const ServiceEditor({required this.vehicles, super.key});
  final List<Map<String, dynamic>> vehicles;
  @override
  State<ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<ServiceEditor> {
  String? vehicleId;
  String type = 'service';
  final title = TextEditingController();
  final dueDate = TextEditingController();
  final dueOdometer = TextEditingController();
  final notes = TextEditingController();
  @override
  void dispose() { for (final c in [title, dueDate, dueOdometer, notes]) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add service reminder'),
        content: SizedBox(width: 540, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: vehicleId, decoration: const InputDecoration(labelText: 'Vehicle'), items: widget.vehicles.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['vehicle_code']} · ${row['registration_no']}'))).toList(), onChanged: (value) => setState(() => vehicleId = value)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Reminder type'), items: const ['service', 'insurance', 'fitness', 'permit', 'puc', 'tyre', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => type = value ?? type)),
          const SizedBox(height: FactorySpacing.sm),
          _field(title, 'Title'),
          _field(dueDate, 'Due date (YYYY-MM-DD)'),
          _field(dueOdometer, 'Due odometer (km)', numeric: true),
          _field(notes, 'Notes'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final date = _blank(dueDate.text);
          final odo = double.tryParse(dueOdometer.text.trim());
          if (vehicleId == null || title.text.trim().length < 3 || (date == null && odo == null)) return;
          if (date != null && DateTime.tryParse(date) == null) return;
          Navigator.pop(context, {'vehicle_id': vehicleId, 'reminder_type': type, 'title': title.text.trim(), 'due_date': date, 'due_odometer_km': odo, 'notes': _blank(notes.text)});
        }, child: const Text('Create'))],
      );
}

class _FleetSection {
  const _FleetSection(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class _FleetMetric extends StatelessWidget {
  const _FleetMetric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: Row(children: [CircleAvatar(backgroundColor: color.withValues(alpha: .10), foregroundColor: color, child: Icon(icon)), const SizedBox(width: FactorySpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(label)]))]),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.actionLabel, required this.actionIcon, required this.onAction, this.secondaryLabel, this.secondaryAction});
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(subtitle)])),
        if (secondaryAction != null) ...[OutlinedButton(onPressed: secondaryAction, child: Text(secondaryLabel ?? 'Action')), const SizedBox(width: FactorySpacing.sm)],
        FilledButton.icon(onPressed: onAction, icon: Icon(actionIcon), label: Text(actionLabel)),
      ]);
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, this.trailing});
  final Map<String, dynamic> trip;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(_tripIcon('${trip['status']}'))),
          title: Text('${trip['trip_no']} · ${trip['origin']} → ${trip['destination']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${_nested(trip, 'fleet_vehicles', 'vehicle_code') ?? ''} · ${_driverFromTrip(trip)} · ${_dateTime(trip['planned_start_at'])}'),
          trailing: trailing ?? _StatusChip('${trip['status']}'),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final normalized = value.toLowerCase();
    final color = switch (normalized) {
      'active' || 'completed' || 'arrived' => FactoryColors.success,
      'maintenance' || 'assigned' || 'planned' || 'due_soon' => FactoryColors.warning,
      'cancelled' || 'out_of_service' || 'inactive' || 'overdue' => FactoryColors.danger,
      _ => FactoryColors.blue,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)), child: Text(value.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w700)));
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyCard('No report rows for this factory.');
    return Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: columns.map((value) => DataColumn(label: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)))).toList(), rows: rows.map((row) => DataRow(cells: row.map((value) => DataCell(Text(value))).toList())).toList())));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Row(children: [const Icon(Icons.inbox_outlined), const SizedBox(width: FactorySpacing.sm), Text(message)])));
}

class _FleetError extends StatelessWidget {
  const _FleetError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: FactoryColors.danger), const SizedBox(height: FactorySpacing.sm), Text(message, textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}

Widget _field(TextEditingController controller, String label, {bool numeric = false}) => Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.sm),
      child: TextField(controller: controller, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null, decoration: InputDecoration(labelText: label)),
    );

List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
String _errorText(Object error) => error is PostgrestException ? error.message : '$error';
String _number(dynamic value) => value == null ? '0' : (value is num ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2)) : '$value');
String _money(dynamic value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return parsed.toStringAsFixed(2);
}
String _date(dynamic value) => value == null ? '—' : '$value'.split('T').first;
String _dateTime(dynamic value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse('$value')?.toLocal();
  if (parsed == null) return '$value';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
}
DateTime? _parseLocalDateTime(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized);
}
dynamic _nested(Map<String, dynamic> row, String parent, String key) {
  final value = row[parent];
  return value is Map ? value[key] : null;
}
String _driverName(Map<String, dynamic> row) {
  final employee = row['employees'];
  return employee is Map ? '${employee['full_name'] ?? employee['employee_code'] ?? 'Driver'}' : 'Driver';
}
String _driverFromTrip(Map<String, dynamic> row) {
  final driver = row['fleet_drivers'];
  if (driver is! Map) return 'Driver';
  final employee = driver['employees'];
  return employee is Map ? '${employee['full_name'] ?? 'Driver'}' : 'Driver';
}
String _vehicleLabel(FleetSnapshot data, dynamic id) => _labelById(data.vehicles, id, 'vehicle_code');
String _driverLabel(FleetSnapshot data, dynamic id) => _labelByDriver(data.drivers, id);
String _labelById(List<Map<String, dynamic>> rows, dynamic id, String field) => '${rows.where((row) => row['id'] == id).firstOrNull?[field] ?? 'Unknown'}';
String _labelByDriver(List<Map<String, dynamic>> rows, dynamic id) {
  final row = rows.where((row) => row['id'] == id).firstOrNull;
  return row == null ? 'Unknown driver' : _driverName(row);
}
IconData _vehicleIcon(String? type) => switch (type) { 'tanker' => Icons.oil_barrel_outlined, 'van' => Icons.airport_shuttle_outlined, 'pickup' => Icons.fire_truck_outlined, 'forklift' => Icons.forklift, _ => Icons.local_shipping_outlined };
IconData _tripIcon(String status) => switch (status) { 'completed' => Icons.check_circle_outline, 'started' => Icons.play_circle_outline, 'arrived' => Icons.location_on_outlined, 'cancelled' => Icons.cancel_outlined, _ => Icons.schedule_outlined };
IconData _dueIcon(String state) => switch (state) { 'overdue' => Icons.error_outline, 'due_soon' => Icons.warning_amber_outlined, _ => Icons.event_available_outlined };
