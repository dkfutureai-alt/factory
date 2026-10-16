import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryDriverPage extends StatefulWidget {
  const DeliveryDriverPage({super.key});

  @override
  State<DeliveryDriverPage> createState() => _DeliveryDriverPageState();
}

class _DeliveryDriverPageState extends State<DeliveryDriverPage> {
  late Future<DriverDeliverySnapshot> future;
  String? selectedId;

  DriverDeliveryRepository get repository =>
      DriverDeliveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load();
  }

  void reload() => setState(() => future = repository.load());

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
      if (mounted) message(_deliveryError(e), error: true);
    }
  }

  Future<double?> askOdometer(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Current odometer (km)',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) Navigator.pop(context, parsed);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> startDelivery(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? trip,
  ) async {
    if (trip == null) return message('Fleet trip not found.', error: true);
    final tripStatus = trip['status'] as String;
    double? odometer;
    if (tripStatus == 'planned' || tripStatus == 'assigned') {
      odometer = await askOdometer('Start delivery trip');
      if (odometer == null) return;
    }
    await run(
      () => repository.startDelivery(
        delivery['id'] as String,
        trip['id'] as String,
        tripStatus,
        odometer,
      ),
      'Delivery trip started.',
    );
  }

  Future<void> arrive(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? trip,
  ) async {
    if (trip == null) return message('Fleet trip not found.', error: true);
    final tripStatus = trip['status'] as String;
    double? odometer;
    if (tripStatus == 'started') {
      odometer = await askOdometer('Arrive at customer');
      if (odometer == null) return;
    }
    await run(
      () => repository.arrive(
        delivery['id'] as String,
        trip['id'] as String,
        tripStatus,
        odometer,
      ),
      'Arrival confirmed.',
    );
  }

  Future<void> completeDelivery(Map<String, dynamic> delivery) async {
    final receiver = TextEditingController();
    final phone = TextEditingController();
    final photoRef = TextEditingController();
    final signatureRef = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete delivery'),
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Column(
            children: [
              TextField(
                controller: receiver,
                decoration: const InputDecoration(labelText: 'Receiver name *'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Receiver phone'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: photoRef,
                decoration: const InputDecoration(
                  labelText: 'POD photo reference',
                  helperText: 'Photo or signature reference is required.',
                ),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: signatureRef,
                decoration: const InputDecoration(labelText: 'Signature reference'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Delivery note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm delivery'),
          ),
        ],
      ),
    );
    final values = {
      'receiver': receiver.text.trim(),
      'phone': phone.text.trim(),
      'photo': photoRef.text.trim(),
      'signature': signatureRef.text.trim(),
      'note': note.text.trim(),
    };
    receiver.dispose();
    phone.dispose();
    photoRef.dispose();
    signatureRef.dispose();
    note.dispose();
    if (accepted != true) return;
    if ((values['receiver'] ?? '').length < 2) {
      return message('Receiver name is required.', error: true);
    }
    if ((values['photo'] ?? '').isEmpty && (values['signature'] ?? '').isEmpty) {
      return message('Add a POD photo or signature reference.', error: true);
    }
    await run(
      () => repository.completeDelivery(delivery['id'] as String, values),
      'Delivery completed with proof of delivery.',
    );
  }

  Future<void> recordReturnable(
    DriverDeliverySnapshot data,
    Map<String, dynamic> delivery,
  ) async {
    if (data.returnableItems.isEmpty) {
      return message('No returnable item is configured.', error: true);
    }
    String? itemId = data.returnableItems.first['id'] as String;
    String condition = 'good';
    final quantity = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pickup returnable stock'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Returnable item'),
                  items: data.returnableItems
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['name']} · ${row['sku']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => itemId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: const [
                    DropdownMenuItem(value: 'good', child: Text('Good')),
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) => setDialogState(() => condition = value ?? 'good'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save pickup'),
            ),
          ],
        ),
      ),
    );
    final qty = double.tryParse(quantity.text.trim());
    final notes = note.text.trim();
    quantity.dispose();
    note.dispose();
    if (accepted != true || itemId == null || qty == null || qty <= 0) return;
    await run(
      () => repository.recordReturnable(
        delivery['id'] as String,
        itemId!,
        qty,
        condition,
        notes,
      ),
      'Returnable stock added to vehicle inventory.',
    );
  }

  Future<void> reportException(Map<String, dynamic> delivery) async {
    String type = 'damage';
    final details = TextEditingController();
    final quantity = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report delivery exception'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Exception type'),
                  items: const [
                    DropdownMenuItem(value: 'shortage', child: Text('Shortage')),
                    DropdownMenuItem(value: 'damage', child: Text('Damage')),
                    DropdownMenuItem(value: 'customer_rejected', child: Text('Customer rejected')),
                    DropdownMenuItem(value: 'address_unreachable', child: Text('Address unreachable')),
                    DropdownMenuItem(value: 'vehicle_issue', child: Text('Vehicle issue')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? 'other'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity (optional)'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Details *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    final detailText = details.text.trim();
    final qty = double.tryParse(quantity.text.trim());
    details.dispose();
    quantity.dispose();
    if (accepted != true || detailText.length < 3) return;
    await run(
      () => repository.reportException(
        delivery['id'] as String,
        type,
        detailText,
        qty,
      ),
      'Delivery exception reported.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery'),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder<DriverDeliverySnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DeliveryError(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        if (data.deliveries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(FactorySpacing.lg),
              child: Text('No delivery is assigned to you.'),
            ),
          );
        }
        if (selectedId == null || !data.deliveries.any((row) => row['id'] == selectedId)) {
          selectedId = data.deliveries.first['id'] as String;
        }
        final delivery = data.deliveries.firstWhere((row) => row['id'] == selectedId);
        final trip = data.trip(delivery['trip_id']);
        final lines = data.linesFor(delivery['id']);
        final exceptions = data.exceptionsFor(delivery['id']);
        final pickup = data.pickup(delivery['id']);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.md),
            children: [
              if (data.deliveries.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(labelText: 'Assigned delivery'),
                  items: data.deliveries
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['delivery_no']} · ${data.customerName(row)}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedId = value),
                ),
              if (data.deliveries.length > 1) const SizedBox(height: FactorySpacing.md),
              _DeliveryHero(data: data, delivery: delivery, trip: trip),
              const SizedBox(height: FactorySpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loaded items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: FactorySpacing.sm),
                      for (final line in lines)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(data.itemName(line['item_id'])),
                          subtitle: Text('Planned ${line['planned_quantity']}'),
                          trailing: Text('${line['delivered_quantity']} / ${line['loaded_quantity']}'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.md),
              _PrimaryAction(
                delivery: delivery,
                trip: trip,
                onStart: () => startDelivery(delivery, trip),
                onArrive: () => arrive(delivery, trip),
                onComplete: () => completeDelivery(delivery),
              ),
              const SizedBox(height: FactorySpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Returnables', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(pickup == null ? 'No returnable pickup recorded.' : 'Pickup status: ${_deliveryLabel(pickup['status'] as String)}'),
                      const SizedBox(height: FactorySpacing.sm),
                      if (delivery['status'] == 'arrived' || delivery['status'] == 'delivered')
                        OutlinedButton.icon(
                          onPressed: () => recordReturnable(data, delivery),
                          icon: const Icon(Icons.recycling_outlined),
                          label: const Text('Add returnable pickup'),
                        ),
                      if (pickup != null && pickup['status'] == 'open')
                        FilledButton.tonal(
                          onPressed: () => run(
                            () => repository.completeReturnables(delivery['id'] as String),
                            'Returnable pickup closed.',
                          ),
                          child: const Text('Close returnable pickup'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Exceptions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          TextButton.icon(
                            onPressed: () => reportException(delivery),
                            icon: const Icon(Icons.report_problem_outlined),
                            label: const Text('Report'),
                          ),
                        ],
                      ),
                      if (exceptions.isEmpty)
                        const Text('No exceptions reported.')
                      else
                        for (final row in exceptions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(row['status'] == 'open' ? Icons.warning_amber : Icons.check_circle_outline),
                            title: Text(_deliveryLabel(row['exception_type'] as String)),
                            subtitle: Text(row['details'] as String),
                            trailing: Text(_deliveryLabel(row['status'] as String)),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class DriverDeliveryRepository {
  DriverDeliveryRepository(this.client);
  final SupabaseClient client;

  Future<DriverDeliverySnapshot> load() async {
    final deliveries = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_deliveries')
          .select()
          .neq('status', 'cancelled')
          .order('created_at', ascending: false),
    );
    final lines = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_delivery_lines')
          .select('delivery_id,item_id,planned_quantity,loaded_quantity,delivered_quantity'),
    );
    final trips = List<Map<String, dynamic>>.from(
      await client
          .from('fleet_trips')
          .select('id,trip_no,status,origin,destination,vehicle_id,started_at,arrived_at'),
    );
    final vehicles = List<Map<String, dynamic>>.from(
      await client
          .from('fleet_vehicles')
          .select('id,registration_no,vehicle_code'),
    );
    final orders = List<Map<String, dynamic>>.from(
      await client
          .from('sales_orders')
          .select('id,sales_order_no,customer_id'),
    );
    final customers = List<Map<String, dynamic>>.from(
      await client
          .from('business_partners')
          .select('id,name,address_line1,city,state,phone'),
    );
    final items = List<Map<String, dynamic>>.from(
      await client
          .from('inventory_items')
          .select('id,sku,name,item_type,is_returnable')
          .order('name'),
    );
    final pickups = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_returnable_pickups')
          .select('id,delivery_id,status,completed_at'),
    );
    final exceptions = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_delivery_exceptions')
          .select('id,delivery_id,exception_type,quantity,details,status,created_at')
          .order('created_at', ascending: false),
    );
    return DriverDeliverySnapshot(
      deliveries: deliveries,
      lines: lines,
      trips: trips,
      vehicles: vehicles,
      orders: orders,
      customers: customers,
      items: items,
      pickups: pickups,
      exceptions: exceptions,
    );
  }

  Future<void> startDelivery(
    String deliveryId,
    String tripId,
    String tripStatus,
    double? odometer,
  ) async {
    if (tripStatus == 'planned' || tripStatus == 'assigned') {
      await client.rpc(
        'fleet_start_trip',
        params: {
          'p_trip_id': tripId,
          'p_odometer_km': odometer,
          'p_notes': 'Started from Delivery workspace',
        },
      );
    }
    await client.rpc(
      'dispatch_begin_delivery',
      params: {'p_delivery_id': deliveryId},
    );
  }

  Future<void> arrive(
    String deliveryId,
    String tripId,
    String tripStatus,
    double? odometer,
  ) async {
    if (tripStatus == 'started') {
      await client.rpc(
        'fleet_mark_trip_arrived',
        params: {
          'p_trip_id': tripId,
          'p_odometer_km': odometer,
          'p_notes': 'Arrived from Delivery workspace',
        },
      );
    }
    await client.rpc(
      'dispatch_mark_arrived',
      params: {'p_delivery_id': deliveryId},
    );
  }

  Future<void> completeDelivery(String deliveryId, Map<String, String> values) async {
    await client.rpc(
      'dispatch_complete_delivery',
      params: {
        'p_delivery_id': deliveryId,
        'p_receiver_name': values['receiver'],
        'p_receiver_phone': _nullable(values['phone']),
        'p_pod_photo_ref': _nullable(values['photo']),
        'p_pod_signature_ref': _nullable(values['signature']),
        'p_notes': _nullable(values['note']),
      },
    );
  }

  Future<void> recordReturnable(
    String deliveryId,
    String itemId,
    double quantity,
    String condition,
    String notes,
  ) async {
    await client.rpc(
      'dispatch_record_returnable',
      params: {
        'p_delivery_id': deliveryId,
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_condition': condition,
        'p_notes': _nullable(notes),
      },
    );
  }

  Future<void> completeReturnables(String deliveryId) async {
    await client.rpc(
      'dispatch_complete_returnables',
      params: {'p_delivery_id': deliveryId, 'p_notes': 'Closed by driver'},
    );
  }

  Future<void> reportException(
    String deliveryId,
    String type,
    String details,
    double? quantity,
  ) async {
    await client.rpc(
      'dispatch_report_exception',
      params: {
        'p_delivery_id': deliveryId,
        'p_exception_type': type,
        'p_details': details,
        'p_item_id': null,
        'p_quantity': quantity,
      },
    );
  }
}

class DriverDeliverySnapshot {
  const DriverDeliverySnapshot({
    required this.deliveries,
    required this.lines,
    required this.trips,
    required this.vehicles,
    required this.orders,
    required this.customers,
    required this.items,
    required this.pickups,
    required this.exceptions,
  });

  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> lines;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> pickups;
  final List<Map<String, dynamic>> exceptions;

  List<Map<String, dynamic>> get returnableItems => items
      .where((row) => row['is_returnable'] == true || row['item_type'] == 'cylinder')
      .toList();

  Map<String, dynamic>? trip(Object? id) => _driverFind(trips, id);

  List<Map<String, dynamic>> linesFor(Object? id) =>
      lines.where((row) => row['delivery_id'] == id).toList();

  List<Map<String, dynamic>> exceptionsFor(Object? id) =>
      exceptions.where((row) => row['delivery_id'] == id).toList();

  Map<String, dynamic>? pickup(Object? id) {
    for (final row in pickups) {
      if (row['delivery_id'] == id) return row;
    }
    return null;
  }

  String itemName(Object? id) => _driverFind(items, id)?['name'] as String? ?? 'Item';

  String customerName(Map<String, dynamic> delivery) {
    final order = _driverFind(orders, delivery['sales_order_id']);
    final customer = order == null ? null : _driverFind(customers, order['customer_id']);
    return customer?['name'] as String? ?? 'Customer';
  }

  String customerAddress(Map<String, dynamic> delivery) {
    final order = _driverFind(orders, delivery['sales_order_id']);
    final customer = order == null ? null : _driverFind(customers, order['customer_id']);
    if (customer == null) return '';
    return [customer['address_line1'], customer['city'], customer['state']]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }

  String vehicleLabel(Map<String, dynamic>? trip) {
    final vehicle = trip == null ? null : _driverFind(vehicles, trip['vehicle_id']);
    return vehicle == null ? 'Vehicle' : '${vehicle['registration_no']} · ${vehicle['vehicle_code']}';
  }
}

class _DeliveryHero extends StatelessWidget {
  const _DeliveryHero({required this.data, required this.delivery, required this.trip});
  final DriverDeliverySnapshot data;
  final Map<String, dynamic> delivery;
  final Map<String, dynamic>? trip;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY\'S DELIVERY', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: FactorySpacing.xs),
          Text(
            delivery['delivery_no'] as String,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: FactorySpacing.sm),
          Text(data.customerName(delivery), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(data.customerAddress(delivery)),
          const SizedBox(height: FactorySpacing.md),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 18),
              const SizedBox(width: FactorySpacing.xs),
              Expanded(child: Text(data.vehicleLabel(trip))),
              Chip(label: Text(_deliveryLabel(delivery['status'] as String))),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.delivery,
    required this.trip,
    required this.onStart,
    required this.onArrive,
    required this.onComplete,
  });
  final Map<String, dynamic> delivery;
  final Map<String, dynamic>? trip;
  final VoidCallback onStart;
  final VoidCallback onArrive;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final status = delivery['status'] as String;
    if (status == 'loaded') {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.route_outlined),
        label: const Text('Start delivery'),
      );
    }
    if (status == 'in_transit') {
      return FilledButton.icon(
        onPressed: onArrive,
        icon: const Icon(Icons.location_on_outlined),
        label: const Text('Arrive at customer'),
      );
    }
    if (status == 'arrived') {
      return FilledButton.icon(
        onPressed: onComplete,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Complete delivery & POD'),
      );
    }
    if (status == 'ready_to_load') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.md),
          child: Text('Waiting for Dispatch Admin to confirm vehicle load.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: FactorySpacing.sm),
            Expanded(child: Text('Delivery ${_deliveryLabel(status)}')),
          ],
        ),
      ),
    );
  }
}

class _DeliveryError extends StatelessWidget {
  const _DeliveryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52),
          const SizedBox(height: FactorySpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: FactorySpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Map<String, dynamic>? _driverFind(List<Map<String, dynamic>> rows, Object? id) {
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

String? _nullable(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _deliveryLabel(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _deliveryError(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
