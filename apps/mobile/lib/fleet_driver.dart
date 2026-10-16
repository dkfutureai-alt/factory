import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FleetDriverPage extends StatefulWidget {
  const FleetDriverPage({super.key});

  @override
  State<FleetDriverPage> createState() => _FleetDriverPageState();
}

class _FleetDriverPageState extends State<FleetDriverPage> {
  late Future<DriverFleetSnapshot> future;
  DriverFleetRepository get repository => DriverFleetRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load();
  }

  void reload() => setState(() => future = repository.load());

  void message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? Theme.of(context).colorScheme.error : null));
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

  Future<double?> askOdometer(String title, double minimum) async {
    final controller = TextEditingController(text: minimum.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Odometer (km)', helperText: 'Must be at least ${minimum.toStringAsFixed(0)} km'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final value = double.tryParse(controller.text.trim());
            if (value != null && value >= minimum) Navigator.pop(context, value);
          }, child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> startTrip(DriverFleetSnapshot data, Map<String, dynamic> trip) async {
    final min = _num(data.vehicle?['current_odometer_km']);
    final value = await askOdometer('Start ${trip['trip_no']}', min);
    if (value == null) return;
    await run(() => repository.startTrip(trip['id'] as String, value), 'Trip started.');
  }

  Future<void> arriveTrip(DriverFleetSnapshot data, Map<String, dynamic> trip) async {
    final min = _max(_num(data.vehicle?['current_odometer_km']), _num(trip['start_odometer_km']));
    final value = await askOdometer('Mark destination reached', min);
    if (value == null) return;
    await run(() => repository.arriveTrip(trip['id'] as String, value), 'Arrival recorded.');
  }

  Future<void> completeTrip(DriverFleetSnapshot data, Map<String, dynamic> trip) async {
    final min = _max(_num(data.vehicle?['current_odometer_km']), _num(trip['arrival_odometer_km']));
    final value = await askOdometer('Complete ${trip['trip_no']}', min);
    if (value == null) return;
    await run(() => repository.completeTrip(trip['id'] as String, value), 'Trip completed.');
  }

  Future<void> addFuel(DriverFleetSnapshot data) async {
    final vehicle = data.vehicle;
    final driver = data.driver;
    if (vehicle == null || driver == null) return message('No active vehicle assignment found.', error: true);
    if (vehicle['fuel_type'] == 'electric') return message('This vehicle does not accept liquid fuel entries.', error: true);
    final activeTrip = data.trips.where((row) => const {'assigned', 'started', 'arrived'}.contains(row['status'])).firstOrNull;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DriverFuelEditor(vehicle: vehicle, activeTrip: activeTrip),
    );
    if (draft == null) return;
    await run(() => repository.recordFuel(vehicle['id'] as String, driver['id'] as String, activeTrip?['id'] as String?, draft), 'Fuel entry saved.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fleet · Driver'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
        body: FutureBuilder<DriverFleetSnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _DriverError(message: '${snapshot.error}', onRetry: reload);
            final data = snapshot.requireData;
            if (data.driver == null) return const _DriverEmpty(message: 'Your account is not linked to an active fleet driver record.');
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.md),
                children: [
                  _DriverHero(data: data),
                  const SizedBox(height: FactorySpacing.md),
                  Row(children: [
                    Expanded(child: _QuickAction(icon: Icons.route_outlined, label: 'My trips', onTap: () => _showTrips(context, data))),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(child: _QuickAction(icon: Icons.local_gas_station_outlined, label: 'Fuel entry', onTap: () => addFuel(data))),
                  ]),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Today & active trips', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: FactorySpacing.sm),
                  if (data.activeTrips.isEmpty) const _DriverEmpty(message: 'No assigned or active trip right now.'),
                  for (final trip in data.activeTrips)
                    DriverTripCard(
                      trip: trip,
                      onStart: trip['status'] == 'assigned' || trip['status'] == 'planned' ? () => startTrip(data, trip) : null,
                      onArrive: trip['status'] == 'started' ? () => arriveTrip(data, trip) : null,
                      onComplete: trip['status'] == 'arrived' ? () => completeTrip(data, trip) : null,
                    ),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Vehicle & documents', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: FactorySpacing.sm),
                  _VehicleCard(data: data),
                  const SizedBox(height: FactorySpacing.md),
                  _LicenceCard(driver: data.driver!),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Recent fuel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: FactorySpacing.sm),
                  if (data.fuel.isEmpty) const _DriverEmpty(message: 'No fuel entry recorded yet.'),
                  for (final row in data.fuel.take(10))
                    Card(child: ListTile(leading: const Icon(Icons.local_gas_station_outlined), title: Text('${_number(row['quantity_liters'])} L · ₹${_money(row['total_amount'])}'), subtitle: Text('${_dateTime(row['filled_at'])} · ${_number(row['odometer_km'])} km${row['vendor'] == null ? '' : ' · ${row['vendor']}'}'))),
                ],
              ),
            );
          },
        ),
      );

  void _showTrips(BuildContext context, DriverFleetSnapshot data) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DriverTripsPage(data: data)));
  }
}

class DriverFleetSnapshot {
  const DriverFleetSnapshot({required this.employee, required this.driver, required this.vehicle, required this.assignment, required this.trips, required this.fuel});
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? vehicle;
  final Map<String, dynamic>? assignment;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> fuel;

  List<Map<String, dynamic>> get activeTrips => trips.where((row) => const {'planned', 'assigned', 'started', 'arrived'}.contains(row['status'])).toList();
}

class DriverFleetRepository {
  DriverFleetRepository(this.client);
  final SupabaseClient client;

  Future<DriverFleetSnapshot> load() async {
    final mine = await client.rpc('my_employee_record') as List<dynamic>;
    if (mine.isEmpty) return const DriverFleetSnapshot(employee: null, driver: null, vehicle: null, assignment: null, trips: [], fuel: []);
    final employee = Map<String, dynamic>.from(mine.first as Map);
    final employeeId = employee['employee_id'] as String;
    final drivers = await client.from('fleet_drivers').select('id,factory_id,employee_id,license_no,license_type,license_expiry,emergency_phone,status,notes').eq('employee_id', employeeId).eq('status', 'active').limit(1);
    if (drivers.isEmpty) return DriverFleetSnapshot(employee: employee, driver: null, vehicle: null, assignment: null, trips: const [], fuel: const []);
    final driver = Map<String, dynamic>.from(drivers.first);
    final driverId = driver['id'] as String;
    final assignments = await client.from('fleet_vehicle_driver_assignments').select('id,vehicle_id,driver_id,effective_from,ended_at,notes').eq('driver_id', driverId).filter('ended_at', 'is', null).limit(1);
    Map<String, dynamic>? assignment;
    Map<String, dynamic>? vehicle;
    if (assignments.isNotEmpty) {
      assignment = Map<String, dynamic>.from(assignments.first);
      final vehicles = await client.from('fleet_vehicles').select('id,vehicle_code,registration_no,vehicle_type,make,model,fuel_type,capacity_quantity,capacity_unit,current_odometer_km,insurance_expiry,fitness_expiry,permit_expiry,puc_expiry,status').eq('id', assignment['vehicle_id']).limit(1);
      if (vehicles.isNotEmpty) vehicle = Map<String, dynamic>.from(vehicles.first);
    }
    final trips = await client.from('fleet_trips').select('id,trip_no,vehicle_id,driver_id,origin,destination,status,planned_start_at,planned_end_at,started_at,arrived_at,completed_at,start_odometer_km,arrival_odometer_km,end_odometer_km,cancellation_reason,notes').eq('driver_id', driverId).order('planned_start_at', ascending: false).limit(100);
    final fuel = await client.from('fleet_fuel_entries').select('id,vehicle_id,driver_id,trip_id,fuel_type,quantity_liters,price_per_liter,total_amount,odometer_km,filled_at,vendor,receipt_reference,notes').eq('driver_id', driverId).order('filled_at', ascending: false).limit(50);
    return DriverFleetSnapshot(employee: employee, driver: driver, vehicle: vehicle, assignment: assignment, trips: _rows(trips), fuel: _rows(fuel));
  }

  Future<void> startTrip(String id, double odometer) async => client.rpc('fleet_start_trip', params: {'p_trip_id': id, 'p_odometer_km': odometer, 'p_notes': 'Started from driver mobile'});
  Future<void> arriveTrip(String id, double odometer) async => client.rpc('fleet_mark_trip_arrived', params: {'p_trip_id': id, 'p_odometer_km': odometer, 'p_notes': 'Arrival recorded from driver mobile'});
  Future<void> completeTrip(String id, double odometer) async => client.rpc('fleet_complete_trip', params: {'p_trip_id': id, 'p_odometer_km': odometer, 'p_notes': 'Completed from driver mobile'});

  Future<void> recordFuel(String vehicleId, String driverId, String? tripId, Map<String, dynamic> d) async => client.rpc('fleet_record_fuel', params: {
        'p_vehicle_id': vehicleId,
        'p_driver_id': driverId,
        'p_trip_id': tripId,
        'p_quantity_liters': d['quantity_liters'],
        'p_price_per_liter': d['price_per_liter'],
        'p_odometer_km': d['odometer_km'],
        'p_vendor': d['vendor'],
        'p_receipt_reference': d['receipt_reference'],
        'p_notes': d['notes'],
      });
}

class _DriverHero extends StatelessWidget {
  const _DriverHero({required this.data});
  final DriverFleetSnapshot data;
  @override
  Widget build(BuildContext context) {
    final employee = data.employee;
    final vehicle = data.vehicle;
    return Container(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      decoration: BoxDecoration(color: FactoryColors.navy, borderRadius: BorderRadius.circular(FactoryRadius.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(backgroundColor: Colors.white, foregroundColor: FactoryColors.navy, child: Icon(Icons.person_outline)), const SizedBox(width: FactorySpacing.sm), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${employee?['full_name'] ?? 'Driver'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text('Driver · ${employee?['employee_code'] ?? ''}', style: const TextStyle(color: Colors.white70))]))]),
        const SizedBox(height: FactorySpacing.lg),
        Text(vehicle == null ? 'No vehicle assigned' : '${vehicle['vehicle_code']} · ${vehicle['registration_no']}', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
        if (vehicle != null) Text('${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} · ${_number(vehicle['current_odometer_km'])} km', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(FactoryRadius.lg), onTap: onTap, child: Padding(padding: const EdgeInsets.all(FactorySpacing.md), child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: FactorySpacing.sm), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right)]))));
}

class DriverTripCard extends StatelessWidget {
  const DriverTripCard({required this.trip, this.onStart, this.onArrive, this.onComplete, super.key});
  final Map<String, dynamic> trip;
  final VoidCallback? onStart;
  final VoidCallback? onArrive;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${trip['trip_no']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))), _DriverStatus('${trip['status']}')]),
            const SizedBox(height: FactorySpacing.xs),
            Row(children: [const Icon(Icons.trip_origin, size: 18, color: FactoryColors.success), const SizedBox(width: 6), Expanded(child: Text('${trip['origin']}'))]),
            const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(height: 16, child: VerticalDivider(width: 2))),
            Row(children: [const Icon(Icons.location_on, size: 18, color: FactoryColors.danger), const SizedBox(width: 6), Expanded(child: Text('${trip['destination']}'))]),
            const SizedBox(height: FactorySpacing.sm),
            Text('Planned ${_dateTime(trip['planned_start_at'])}', style: Theme.of(context).textTheme.bodySmall),
            if (onStart != null || onArrive != null || onComplete != null) ...[
              const SizedBox(height: FactorySpacing.md),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: onStart ?? onArrive ?? onComplete,
                icon: Icon(onStart != null ? Icons.play_arrow : onArrive != null ? Icons.location_on_outlined : Icons.check),
                label: Text(onStart != null ? 'Start trip' : onArrive != null ? 'Mark arrived' : 'Complete trip'),
              )),
            ],
          ]),
        ),
      );
}

class DriverTripsPage extends StatelessWidget {
  const DriverTripsPage({required this.data, super.key});
  final DriverFleetSnapshot data;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My trips')),
        body: ListView(
          padding: const EdgeInsets.all(FactorySpacing.md),
          children: [
            for (final trip in data.trips) DriverTripCard(trip: trip),
            if (data.trips.isEmpty) const _DriverEmpty(message: 'No trip history found.'),
          ],
        ),
      );
}

class DriverFuelEditor extends StatefulWidget {
  const DriverFuelEditor({required this.vehicle, required this.activeTrip, super.key});
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? activeTrip;
  @override
  State<DriverFuelEditor> createState() => _DriverFuelEditorState();
}

class _DriverFuelEditorState extends State<DriverFuelEditor> {
  late final TextEditingController odometer = TextEditingController(text: '${widget.vehicle['current_odometer_km'] ?? 0}');
  final quantity = TextEditingController();
  final rate = TextEditingController();
  final vendor = TextEditingController();
  final receipt = TextEditingController();
  final notes = TextEditingController();

  @override
  void dispose() { for (final c in [odometer, quantity, rate, vendor, receipt, notes]) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final q = double.tryParse(quantity.text.trim()) ?? 0;
    final r = double.tryParse(rate.text.trim()) ?? 0;
    return AlertDialog(
      title: const Text('Add fuel entry'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Card(child: ListTile(leading: const Icon(Icons.local_shipping_outlined), title: Text('${widget.vehicle['vehicle_code']} · ${widget.vehicle['registration_no']}'), subtitle: Text(widget.activeTrip == null ? 'No active trip' : '${widget.activeTrip!['trip_no']} · ${widget.activeTrip!['destination']}'))),
        _field(odometer, 'Odometer (km)', numeric: true),
        _field(quantity, 'Fuel quantity (litres)', numeric: true, onChanged: (_) => setState(() {})),
        _field(rate, 'Rate per litre', numeric: true, onChanged: (_) => setState(() {})),
        Align(alignment: Alignment.centerRight, child: Text('Total ₹${(q * r).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900))),
        const SizedBox(height: FactorySpacing.sm),
        _field(vendor, 'Fuel station / vendor'),
        _field(receipt, 'Receipt reference'),
        _field(notes, 'Notes'),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final odo = double.tryParse(odometer.text.trim());
          final quantityValue = double.tryParse(quantity.text.trim());
          final rateValue = double.tryParse(rate.text.trim());
          final current = _num(widget.vehicle['current_odometer_km']);
          if (odo == null || odo < current || quantityValue == null || quantityValue <= 0 || rateValue == null || rateValue < 0) return;
          Navigator.pop(context, {'odometer_km': odo, 'quantity_liters': quantityValue, 'price_per_liter': rateValue, 'vendor': _blank(vendor.text), 'receipt_reference': _blank(receipt.text), 'notes': _blank(notes.text)});
        }, child: const Text('Save')),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.data});
  final DriverFleetSnapshot data;
  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    if (vehicle == null) return const _DriverEmpty(message: 'No active vehicle assignment.');
    return Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const CircleAvatar(child: Icon(Icons.local_shipping_outlined)), const SizedBox(width: FactorySpacing.sm), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${vehicle['vehicle_code']} · ${vehicle['registration_no']}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('${vehicle['vehicle_type']} · ${vehicle['fuel_type']}')]))]),
      const Divider(height: FactorySpacing.lg),
      _info('Odometer', '${_number(vehicle['current_odometer_km'])} km'),
      _info('Insurance', _date(vehicle['insurance_expiry'])),
      _info('Fitness', _date(vehicle['fitness_expiry'])),
      _info('Permit', _date(vehicle['permit_expiry'])),
      _info('PUC', _date(vehicle['puc_expiry'])),
    ])));
  }
}

class _LicenceCard extends StatelessWidget {
  const _LicenceCard({required this.driver});
  final Map<String, dynamic> driver;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.badge_outlined, color: FactoryColors.blue), const SizedBox(width: FactorySpacing.sm), Text('Driving licence', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]),
        const SizedBox(height: FactorySpacing.sm),
        _info('Licence', '${driver['license_no']}'),
        _info('Type', '${driver['license_type']}'),
        _info('Valid until', _date(driver['license_expiry'])),
        if (driver['emergency_phone'] != null) _info('Emergency phone', '${driver['emergency_phone']}'),
      ])));
}

class _DriverStatus extends StatelessWidget {
  const _DriverStatus(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value) { 'completed' || 'arrived' => FactoryColors.success, 'started' => FactoryColors.blue, 'cancelled' => FactoryColors.danger, _ => FactoryColors.warning };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)), child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)));
  }
}

class _DriverEmpty extends StatelessWidget {
  const _DriverEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Row(children: [const Icon(Icons.inbox_outlined), const SizedBox(width: FactorySpacing.sm), Expanded(child: Text(message))])));
}

class _DriverError extends StatelessWidget {
  const _DriverError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: FactoryColors.danger), const SizedBox(height: FactorySpacing.sm), Text(message, textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}

Widget _field(TextEditingController controller, String label, {bool numeric = false, ValueChanged<String>? onChanged}) => Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.sm),
      child: TextField(controller: controller, onChanged: onChanged, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null, decoration: InputDecoration(labelText: label)),
    );
Widget _info(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.black54))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))) ]));
List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
String _errorText(Object error) => error is PostgrestException ? error.message : '$error';
double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
double _max(double a, double b) => a > b ? a : b;
String _number(dynamic value) { final n = _num(value); return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2); }
String _money(dynamic value) => _num(value).toStringAsFixed(2);
String _date(dynamic value) => value == null ? 'Not set' : '$value'.split('T').first;
String _dateTime(dynamic value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse('$value')?.toLocal();
  if (parsed == null) return '$value';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
}
