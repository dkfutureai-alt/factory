import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DispatchManagementPage extends StatefulWidget {
  const DispatchManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<DispatchManagementPage> createState() => _DispatchManagementPageState();
}

class _DispatchManagementPageState extends State<DispatchManagementPage> {
  String? factoryId;
  String filter = 'all';
  String? selectedDeliveryId;
  Future<DispatchSnapshot>? future;

  DispatchRepository get repository =>
      DispatchRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    if (widget.factories.isNotEmpty) {
      factoryId = widget.factories.first['id'] as String;
      future = repository.load(widget.organizationId, factoryId!);
    }
  }

  void reload() {
    final id = factoryId;
    if (id == null) return;
    setState(() => future = repository.load(widget.organizationId, id));
  }

  void chooseFactory(String? id) {
    if (id == null || id == factoryId) return;
    setState(() {
      factoryId = id;
      selectedDeliveryId = null;
      future = repository.load(widget.organizationId, id);
    });
  }

  void message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
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

  Future<void> createDelivery(DispatchSnapshot data) async {
    final usedHandoffs = data.deliveries
        .map((row) => row['warehouse_handoff_id'])
        .toSet();
    final usedTrips = data.deliveries.map((row) => row['trip_id']).toSet();
    final handoffs = data.handoffs
        .where((row) => !usedHandoffs.contains(row['id']))
        .toList();
    final trips = data.trips.where((row) => !usedTrips.contains(row['id'])).toList();
    if (handoffs.isEmpty) {
      return message('No handed-off Warehouse load is waiting for Dispatch.', error: true);
    }
    if (trips.isEmpty) {
      return message('No planned or assigned Fleet trip is available.', error: true);
    }

    String? handoffId = handoffs.first['id'] as String;
    String? tripId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final handoff = handoffs.firstWhere((row) => row['id'] == handoffId);
          final orderId = handoff['sales_order_id'];
          final matchingTrips = trips.where((row) {
            final tripOrder = row['sales_order_id'];
            final tripHandoff = row['warehouse_handoff_id'];
            return (tripOrder == null || tripOrder == orderId) &&
                (tripHandoff == null || tripHandoff == handoffId);
          }).toList();
          if (tripId == null || !matchingTrips.any((row) => row['id'] == tripId)) {
            tripId = matchingTrips.isEmpty ? null : matchingTrips.first['id'] as String;
          }
          return AlertDialog(
            title: const Text('Create delivery'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: handoffId,
                    decoration: const InputDecoration(labelText: 'Warehouse handoff'),
                    items: handoffs
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(row['handoff_no'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      handoffId = value;
                      tripId = null;
                    }),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: tripId,
                    decoration: const InputDecoration(labelText: 'Fleet trip'),
                    items: matchingTrips
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(
                              '${row['trip_no']} · ${row['destination']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => tripId = value),
                  ),
                  if (matchingTrips.isEmpty) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    const Text(
                      'No Fleet trip matches this handoff / Sales order.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: tripId == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Create delivery'),
              ),
            ],
          );
        },
      ),
    );
    if (accepted != true || handoffId == null || tripId == null) return;
    await run(
      () => repository.createDelivery(handoffId!, tripId!),
      'Delivery created and linked to Warehouse + Fleet.',
    );
  }

  Future<void> resolveException(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve exception'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Resolution note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (accepted != true || note.length < 3) return;
    await run(
      () => repository.resolveException(row['id'] as String, note),
      'Delivery exception resolved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.factories.isEmpty) {
      return const Center(child: Text('Create a factory before using Dispatch.'));
    }
    final currentFuture = future;
    if (currentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<DispatchSnapshot>(
      future: currentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DispatchError(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        final visible = filter == 'all'
            ? data.deliveries
            : data.deliveries.where((row) => row['status'] == filter).toList();
        if (selectedDeliveryId == null && visible.isNotEmpty) {
          selectedDeliveryId = visible.first['id'] as String;
        }
        Map<String, dynamic>? selected;
        for (final row in data.deliveries) {
          if (row['id'] == selectedDeliveryId) selected = row;
        }
        final wide = MediaQuery.sizeOf(context).width > 1180;
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            _Header(
              factories: widget.factories,
              factoryId: factoryId!,
              onFactoryChanged: chooseFactory,
              onRefresh: reload,
              onCreate: () => createDelivery(data),
            ),
            const SizedBox(height: FactorySpacing.lg),
            _Metrics(summary: data.summary),
            const SizedBox(height: FactorySpacing.lg),
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
                for (final value in const [
                  'all',
                  'ready_to_load',
                  'loaded',
                  'in_transit',
                  'arrived',
                  'delivered',
                ])
                  FilterChip(
                    selected: filter == value,
                    label: Text(_statusLabel(value)),
                    onSelected: (_) => setState(() => filter = value),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.md),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DeliveryQueue(
                      data: data,
                      deliveries: visible,
                      selectedId: selectedDeliveryId,
                      onSelect: (id) => setState(() => selectedDeliveryId = id),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.md),
                  Expanded(
                    flex: 4,
                    child: _DeliveryDetails(
                      data: data,
                      delivery: selected,
                      onLoad: selected == null
                          ? null
                          : () => run(
                                () => repository.confirmVehicleLoad(
                                  selected!['id'] as String,
                                ),
                                'Vehicle load confirmed. Inventory moved to vehicle.',
                              ),
                      onResolve: resolveException,
                    ),
                  ),
                ],
              )
            else ...[
              _DeliveryQueue(
                data: data,
                deliveries: visible,
                selectedId: selectedDeliveryId,
                onSelect: (id) => setState(() => selectedDeliveryId = id),
              ),
              const SizedBox(height: FactorySpacing.md),
              _DeliveryDetails(
                data: data,
                delivery: selected,
                onLoad: selected == null
                    ? null
                    : () => run(
                          () => repository.confirmVehicleLoad(
                            selected!['id'] as String,
                          ),
                          'Vehicle load confirmed. Inventory moved to vehicle.',
                        ),
                onResolve: resolveException,
              ),
            ],
          ],
        );
      },
    );
  }
}

class DispatchRepository {
  DispatchRepository(this.client);
  final SupabaseClient client;

  Future<DispatchSnapshot> load(String organizationId, String factoryId) async {
    final summaryRaw = await client.rpc(
      'dispatch_dashboard_summary',
      params: {'p_organization_id': organizationId, 'p_factory_id': factoryId},
    );
    final deliveries = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_deliveries')
          .select()
          .eq('factory_id', factoryId)
          .order('created_at', ascending: false),
    );
    final handoffs = List<Map<String, dynamic>>.from(
      await client
          .from('warehouse_dispatch_handoffs')
          .select('id,handoff_no,sales_order_id,status,staging_location_id')
          .eq('factory_id', factoryId)
          .eq('status', 'handed_off')
          .order('created_at', ascending: false),
    );
    final trips = List<Map<String, dynamic>>.from(
      await client
          .from('fleet_trips')
          .select(
            'id,trip_no,sales_order_id,warehouse_handoff_id,vehicle_id,driver_id,status,origin,destination,planned_start_at',
          )
          .eq('factory_id', factoryId)
          .inFilter('status', ['planned', 'assigned', 'started', 'arrived'])
          .order('planned_start_at'),
    );
    final vehicles = List<Map<String, dynamic>>.from(
      await client
          .from('fleet_vehicles')
          .select('id,vehicle_code,registration_no')
          .eq('factory_id', factoryId),
    );
    final drivers = List<Map<String, dynamic>>.from(
      await client
          .from('fleet_drivers')
          .select('id,employee_id')
          .eq('factory_id', factoryId),
    );
    final employees = List<Map<String, dynamic>>.from(
      await client
          .from('employees')
          .select('id,full_name')
          .eq('primary_factory_id', factoryId),
    );
    final orders = List<Map<String, dynamic>>.from(
      await client
          .from('sales_orders')
          .select('id,sales_order_no,customer_id')
          .eq('factory_id', factoryId),
    );
    final customers = List<Map<String, dynamic>>.from(
      await client
          .from('business_partners')
          .select('id,name')
          .eq('organization_id', organizationId),
    );
    final lines = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_delivery_lines')
          .select('delivery_id,item_id,planned_quantity,loaded_quantity,delivered_quantity'),
    );
    final items = List<Map<String, dynamic>>.from(
      await client
          .from('inventory_items')
          .select('id,sku,name,item_type,is_returnable')
          .eq('organization_id', organizationId),
    );
    final pickups = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_returnable_pickups')
          .select('id,delivery_id,status,completed_at')
          .eq('factory_id', factoryId),
    );
    final exceptions = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_delivery_exceptions')
          .select('id,delivery_id,item_id,exception_type,quantity,details,status,resolution_note,created_at')
          .eq('factory_id', factoryId)
          .order('created_at', ascending: false),
    );
    return DispatchSnapshot(
      summary: Map<String, dynamic>.from(summaryRaw as Map),
      deliveries: deliveries,
      handoffs: handoffs,
      trips: trips,
      vehicles: vehicles,
      drivers: drivers,
      employees: employees,
      orders: orders,
      customers: customers,
      lines: lines,
      items: items,
      pickups: pickups,
      exceptions: exceptions,
    );
  }

  Future<void> createDelivery(String handoffId, String tripId) async {
    await client.rpc(
      'dispatch_create_delivery',
      params: {'p_handoff_id': handoffId, 'p_trip_id': tripId},
    );
  }

  Future<void> confirmVehicleLoad(String deliveryId) async {
    await client.rpc(
      'dispatch_confirm_vehicle_load',
      params: {'p_delivery_id': deliveryId},
    );
  }

  Future<void> resolveException(String exceptionId, String note) async {
    await client.rpc(
      'dispatch_resolve_exception',
      params: {'p_exception_id': exceptionId, 'p_resolution_note': note},
    );
  }
}

class DispatchSnapshot {
  const DispatchSnapshot({
    required this.summary,
    required this.deliveries,
    required this.handoffs,
    required this.trips,
    required this.vehicles,
    required this.drivers,
    required this.employees,
    required this.orders,
    required this.customers,
    required this.lines,
    required this.items,
    required this.pickups,
    required this.exceptions,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> handoffs;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> lines;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> pickups;
  final List<Map<String, dynamic>> exceptions;

  String customerName(Map<String, dynamic> delivery) {
    final order = _find(orders, delivery['sales_order_id']);
    final customer = order == null ? null : _find(customers, order['customer_id']);
    return customer?['name'] as String? ?? 'Customer';
  }

  String orderNo(Map<String, dynamic> delivery) =>
      _find(orders, delivery['sales_order_id'])?['sales_order_no'] as String? ?? '—';

  String vehicleLabel(Map<String, dynamic> delivery) {
    final row = _find(vehicles, delivery['vehicle_id']);
    return row == null ? '—' : '${row['registration_no']} · ${row['vehicle_code']}';
  }

  String driverName(Map<String, dynamic> delivery) {
    final driver = _find(drivers, delivery['driver_id']);
    final employee = driver == null ? null : _find(employees, driver['employee_id']);
    return employee?['full_name'] as String? ?? '—';
  }

  String itemName(Object? id) => _find(items, id)?['name'] as String? ?? 'Item';

  List<Map<String, dynamic>> deliveryLines(Object? id) =>
      lines.where((row) => row['delivery_id'] == id).toList();

  List<Map<String, dynamic>> deliveryExceptions(Object? id) =>
      exceptions.where((row) => row['delivery_id'] == id).toList();

  Map<String, dynamic>? pickup(Object? id) {
    for (final row in pickups) {
      if (row['delivery_id'] == id) return row;
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.factories,
    required this.factoryId,
    required this.onFactoryChanged,
    required this.onRefresh,
    required this.onCreate,
  });
  final List<Map<String, dynamic>> factories;
  final String factoryId;
  final ValueChanged<String?> onFactoryChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: FactorySpacing.md,
    runSpacing: FactorySpacing.md,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispatch & Delivery',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const Text('Warehouse handoff → vehicle load → POD → returnables'),
        ],
      ),
      Wrap(
        spacing: FactorySpacing.sm,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: factoryId,
              items: factories
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(row['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: onFactoryChanged,
              decoration: const InputDecoration(labelText: 'Factory'),
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_road),
            label: const Text('Create delivery'),
          ),
        ],
      ),
    ],
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FactorySpacing.md,
    runSpacing: FactorySpacing.md,
    children: [
      _Metric('Ready to load', summary['ready_to_load'], Icons.inventory_outlined),
      _Metric('On vehicle', summary['loaded'], Icons.local_shipping_outlined),
      _Metric('In transit', summary['in_transit'], Icons.route_outlined),
      _Metric('Delivered today', summary['delivered_today'], Icons.task_alt),
      _Metric('Open exceptions', summary['open_exceptions'], Icons.warning_amber),
      _Metric('Returnables open', summary['open_returnables'], Icons.recycling_outlined),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Row(
          children: [
            Icon(icon, color: FactoryColors.blue),
            const SizedBox(width: FactorySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeliveryQueue extends StatelessWidget {
  const _DeliveryQueue({
    required this.data,
    required this.deliveries,
    required this.selectedId,
    required this.onSelect,
  });
  final DispatchSnapshot data;
  final List<Map<String, dynamic>> deliveries;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery queue', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          if (deliveries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: FactorySpacing.xl),
              child: Center(child: Text('No deliveries in this status.')),
            )
          else
            for (final row in deliveries)
              ListTile(
                selected: row['id'] == selectedId,
                onTap: () => onSelect(row['id'] as String),
                leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                title: Text('${row['delivery_no']} · ${data.customerName(row)}'),
                subtitle: Text('${data.orderNo(row)} · ${data.vehicleLabel(row)} · ${data.driverName(row)}'),
                trailing: _StatusChip(status: row['status'] as String),
              ),
        ],
      ),
    ),
  );
}

class _DeliveryDetails extends StatelessWidget {
  const _DeliveryDetails({
    required this.data,
    required this.delivery,
    required this.onLoad,
    required this.onResolve,
  });
  final DispatchSnapshot data;
  final Map<String, dynamic>? delivery;
  final VoidCallback? onLoad;
  final ValueChanged<Map<String, dynamic>> onResolve;

  @override
  Widget build(BuildContext context) {
    final row = delivery;
    if (row == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.xl),
          child: Text('Select a delivery to view details.'),
        ),
      );
    }
    final lines = data.deliveryLines(row['id']);
    final exceptions = data.deliveryExceptions(row['id']);
    final pickup = data.pickup(row['id']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row['delivery_no'] as String,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusChip(status: row['status'] as String),
              ],
            ),
            Text(data.customerName(row)),
            Text('${data.orderNo(row)} · ${data.vehicleLabel(row)}'),
            const Divider(height: FactorySpacing.xl),
            Text('Load', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: FactorySpacing.sm),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(data.itemName(line['item_id']))),
                    Text('${line['delivered_quantity']} / ${line['loaded_quantity']} / ${line['planned_quantity']}'),
                  ],
                ),
              ),
            if (row['status'] == 'ready_to_load') ...[
              const SizedBox(height: FactorySpacing.md),
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Confirm vehicle load'),
              ),
            ],
            const Divider(height: FactorySpacing.xl),
            Text('Returnables', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(pickup == null ? 'No pickup recorded.' : 'Pickup ${_statusLabel(pickup['status'] as String)}'),
            const Divider(height: FactorySpacing.xl),
            Text('Exceptions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (exceptions.isEmpty)
              const Text('No delivery exceptions.')
            else
              for (final exception in exceptions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_statusLabel(exception['exception_type'] as String)),
                  subtitle: Text(exception['details'] as String),
                  trailing: exception['status'] == 'open'
                      ? TextButton(
                          onPressed: () => onResolve(exception),
                          child: const Text('Resolve'),
                        )
                      : const Icon(Icons.check_circle_outline),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Chip(label: Text(_statusLabel(status)));
}

class _DispatchError extends StatelessWidget {
  const _DispatchError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: FactorySpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: FactorySpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Map<String, dynamic>? _find(List<Map<String, dynamic>> rows, Object? id) {
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

String _statusLabel(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
