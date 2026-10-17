import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
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
    } catch (error) {
      if (mounted) message(_errorText(error), error: true);
    }
  }

  Future<double?> askOdometer(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Current odometer',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> startDelivery(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? trip,
  ) async {
    if (trip == null) {
      message('Fleet trip not found.', error: true);
      return;
    }
    final status = trip['status'] as String;
    double? odometer;
    if (status == 'planned' || status == 'assigned') {
      odometer = await askOdometer('Start delivery trip');
      if (odometer == null) return;
    }
    await run(
      () => repository.startDelivery(
        deliveryId: delivery['id'] as String,
        tripId: trip['id'] as String,
        tripStatus: status,
        odometer: odometer,
      ),
      'Delivery trip started.',
    );
  }

  Future<void> arrive(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? trip,
  ) async {
    if (trip == null) {
      message('Fleet trip not found.', error: true);
      return;
    }
    final status = trip['status'] as String;
    double? odometer;
    if (status == 'started') {
      odometer = await askOdometer('Arrive at customer');
      if (odometer == null) return;
    }
    await run(
      () => repository.arrive(
        deliveryId: delivery['id'] as String,
        tripId: trip['id'] as String,
        tripStatus: status,
        odometer: odometer,
      ),
      'Customer arrival confirmed.',
    );
  }

  Future<void> completeTrip(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? trip,
  ) async {
    if (trip == null || trip['status'] != 'arrived') return;
    final odometer = await askOdometer('Complete vehicle trip');
    if (odometer == null) return;
    await run(
      () => repository.completeTrip(
        tripId: trip['id'] as String,
        odometer: odometer,
      ),
      'Vehicle trip completed.',
    );
  }

  Future<void> completeDelivery(Map<String, dynamic> delivery) async {
    final receiver = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    XFile? podPhoto;
    bool selectingPhoto = false;

    Future<void> selectPhoto(
      ImageSource source,
      StateSetter setDialogState,
    ) async {
      setDialogState(() => selectingPhoto = true);
      try {
        final picked = await ImagePicker().pickImage(
          source: source,
          imageQuality: 82,
          maxWidth: 2000,
        );
        if (picked != null) setDialogState(() => podPhoto = picked);
      } finally {
        setDialogState(() => selectingPhoto = false);
      }
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete delivery'),
          scrollable: true,
          content: SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: receiver,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'Receiver name *'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Receiver phone'),
                ),
                const SizedBox(height: FactorySpacing.md),
                Text(
                  'Proof of delivery *',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: FactorySpacing.xs),
                if (podPhoto == null)
                  const Text('Take a delivery photo or choose one from gallery.')
                else
                  Container(
                    padding: const EdgeInsets.all(FactorySpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(FactoryRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline),
                        const SizedBox(width: FactorySpacing.sm),
                        Expanded(
                          child: Text(
                            podPhoto!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove photo',
                          onPressed: selectingPhoto
                              ? null
                              : () => setDialogState(() => podPhoto = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: FactorySpacing.sm),
                Wrap(
                  spacing: FactorySpacing.sm,
                  runSpacing: FactorySpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: selectingPhoto
                          ? null
                          : () => selectPhoto(ImageSource.camera, setDialogState),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectingPhoto
                          ? null
                          : () => selectPhoto(ImageSource.gallery, setDialogState),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.md),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Delivery note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: selectingPhoto
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: selectingPhoto ||
                      receiver.text.trim().length < 2 ||
                      podPhoto == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Upload & confirm'),
            ),
          ],
        ),
      ),
    );

    final receiverValue = receiver.text.trim();
    final phoneValue = phone.text.trim();
    final noteValue = note.text.trim();
    receiver.dispose();
    phone.dispose();
    note.dispose();
    if (accepted != true || podPhoto == null) return;

    await run(
      () => repository.completeDeliveryWithPhoto(
        delivery: delivery,
        receiverName: receiverValue,
        receiverPhone: phoneValue,
        note: noteValue,
        photo: podPhoto!,
      ),
      'Delivery completed and POD photo saved securely.',
    );
  }

  Future<void> recordReturnable(
    DriverDeliverySnapshot data,
    Map<String, dynamic> delivery,
  ) async {
    if (data.returnableItems.isEmpty) {
      message('No returnable item is configured.', error: true);
      return;
    }
    String itemId = data.returnableItems.first['id'] as String;
    String condition = 'good';
    final quantity = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pickup returnable stock'),
          content: SizedBox(
            width: 460,
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
                  onChanged: (value) {
                    if (value != null) setDialogState(() => itemId = value);
                  },
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
                  onChanged: (value) =>
                      setDialogState(() => condition = value ?? 'good'),
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
    final amount = double.tryParse(quantity.text.trim());
    final noteValue = note.text.trim();
    quantity.dispose();
    note.dispose();
    if (accepted != true || amount == null || amount <= 0) return;
    await run(
      () => repository.recordReturnable(
        deliveryId: delivery['id'] as String,
        itemId: itemId,
        quantity: amount,
        condition: condition,
        notes: noteValue,
      ),
      'Returnable stock received onto vehicle.',
    );
  }

  Future<void> reportException(Map<String, dynamic> delivery) async {
    String type = 'damage';
    final quantity = TextEditingController();
    final details = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report delivery exception'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Exception type'),
                  items: const [
                    DropdownMenuItem(value: 'shortage', child: Text('Shortage')),
                    DropdownMenuItem(value: 'damage', child: Text('Damage')),
                    DropdownMenuItem(
                      value: 'customer_rejected',
                      child: Text('Customer rejected'),
                    ),
                    DropdownMenuItem(
                      value: 'address_unreachable',
                      child: Text('Address unreachable'),
                    ),
                    DropdownMenuItem(value: 'vehicle_issue', child: Text('Vehicle issue')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'other'),
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
    final detailsValue = details.text.trim();
    final amount = double.tryParse(quantity.text.trim());
    details.dispose();
    quantity.dispose();
    if (accepted != true || detailsValue.length < 3) return;
    await run(
      () => repository.reportException(
        deliveryId: delivery['id'] as String,
        type: type,
        details: detailsValue,
        quantity: amount,
      ),
      'Delivery exception reported.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Delivery'),
          actions: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<DriverDeliverySnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(message: '${snapshot.error}', onRetry: reload);
            }
            final data = snapshot.requireData;
            if (data.deliveries.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(FactorySpacing.lg),
                  child: Text('No delivery is assigned to this driver.'),
                ),
              );
            }
            if (selectedId == null ||
                !data.deliveries.any((row) => row['id'] == selectedId)) {
              selectedId = data.deliveries.first['id'] as String;
            }
            final delivery = data.deliveries
                .firstWhere((row) => row['id'] == selectedId);
            final trip = data.findTrip(delivery['trip_id']);
            final lines = data.linesFor(delivery['id']);
            final exceptions = data.exceptionsFor(delivery['id']);
            final pickup = data.findPickup(delivery['id']);
            final status = delivery['status'] as String;

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.md),
                children: [
                  if (data.deliveries.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      decoration: const InputDecoration(labelText: 'Assigned delivery'),
                      items: data.deliveries
                          .map(
                            (row) => DropdownMenuItem(
                              value: row['id'] as String,
                              child: Text(
                                '${row['delivery_no']} · ${data.customerName(row)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => selectedId = value),
                    ),
                    const SizedBox(height: FactorySpacing.md),
                  ],
                  _DeliveryHero(data: data, delivery: delivery, trip: trip),
                  const SizedBox(height: FactorySpacing.md),
                  _LoadCard(data: data, lines: lines),
                  const SizedBox(height: FactorySpacing.md),
                  _ActionCard(
                    status: status,
                    tripStatus: trip?['status'] as String?,
                    onStart: () => startDelivery(delivery, trip),
                    onArrive: () => arrive(delivery, trip),
                    onDeliver: () => completeDelivery(delivery),
                    onCompleteTrip: () => completeTrip(delivery, trip),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  _ReturnablesCard(
                    pickup: pickup,
                    canAdd: (status == 'arrived' || status == 'delivered') &&
                        (pickup == null || pickup['status'] == 'open'),
                    onAdd: () => recordReturnable(data, delivery),
                    onClose: pickup?['status'] == 'open'
                        ? () => run(
                              () => repository.completeReturnables(
                                delivery['id'] as String,
                              ),
                              'Returnable pickup closed.',
                            )
                        : null,
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  _ExceptionsCard(
                    exceptions: exceptions,
                    onReport: () => reportException(delivery),
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
  static const podBucket = 'delivery-pod';

  Future<DriverDeliverySnapshot> load() async {
    final deliveries = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_deliveries')
          .select()
          .neq('status', 'cancelled')
          .order('created_at', ascending: false),
    );
    final lines = List<Map<String, dynamic>>.from(
      await client.from('dispatch_delivery_lines').select(
            'delivery_id,item_id,planned_quantity,loaded_quantity,delivered_quantity',
          ),
    );
    final trips = List<Map<String, dynamic>>.from(
      await client.from('fleet_trips').select(
            'id,trip_no,status,origin,destination,vehicle_id,started_at,arrived_at,completed_at',
          ),
    );
    final vehicles = List<Map<String, dynamic>>.from(
      await client.from('fleet_vehicles').select(
            'id,registration_no,vehicle_code',
          ),
    );
    final orders = List<Map<String, dynamic>>.from(
      await client.from('sales_orders').select(
            'id,sales_order_no,customer_id',
          ),
    );
    final customers = List<Map<String, dynamic>>.from(
      await client.from('business_partners').select(
            'id,name,address_line1,city,state,phone',
          ),
    );
    final items = List<Map<String, dynamic>>.from(
      await client
          .from('inventory_items')
          .select('id,sku,name,item_type,is_returnable')
          .order('name'),
    );
    final pickups = List<Map<String, dynamic>>.from(
      await client.from('dispatch_returnable_pickups').select(
            'id,delivery_id,status,completed_at',
          ),
    );
    final exceptions = List<Map<String, dynamic>>.from(
      await client
          .from('dispatch_delivery_exceptions')
          .select(
            'id,delivery_id,exception_type,quantity,details,status,created_at',
          )
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

  Future<void> startDelivery({
    required String deliveryId,
    required String tripId,
    required String tripStatus,
    required double? odometer,
  }) async {
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

  Future<void> arrive({
    required String deliveryId,
    required String tripId,
    required String tripStatus,
    required double? odometer,
  }) async {
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

  Future<void> completeTrip({
    required String tripId,
    required double odometer,
  }) async {
    await client.rpc(
      'fleet_complete_trip',
      params: {
        'p_trip_id': tripId,
        'p_odometer_km': odometer,
        'p_notes': 'Completed from Delivery workspace',
      },
    );
  }

  Future<void> completeDeliveryWithPhoto({
    required Map<String, dynamic> delivery,
    required String receiverName,
    required String receiverPhone,
    required String note,
    required XFile photo,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');

    final extension = _safeImageExtension(photo.name);
    final contentType = _imageContentType(extension);
    final path = '${delivery['organization_id']}/${delivery['factory_id']}/'
        '${delivery['id']}/$userId/'
        '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty) throw StateError('Selected POD photo is empty.');

    await client.storage.from(podBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      await client.rpc(
        'dispatch_complete_delivery',
        params: {
          'p_delivery_id': delivery['id'],
          'p_receiver_name': receiverName,
          'p_receiver_phone': _nullable(receiverPhone),
          'p_pod_photo_ref': path,
          'p_pod_signature_ref': null,
          'p_notes': _nullable(note),
        },
      );
    } catch (_) {
      try {
        await client.storage.from(podBucket).remove([path]);
      } catch (_) {
        // Preserve the original delivery error; storage cleanup can be retried later.
      }
      rethrow;
    }
  }

  Future<void> recordReturnable({
    required String deliveryId,
    required String itemId,
    required double quantity,
    required String condition,
    required String notes,
  }) async {
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
      params: {
        'p_delivery_id': deliveryId,
        'p_notes': 'Closed by assigned driver',
      },
    );
  }

  Future<void> reportException({
    required String deliveryId,
    required String type,
    required String details,
    required double? quantity,
  }) async {
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
      .where(
        (row) => row['is_returnable'] == true || row['item_type'] == 'cylinder',
      )
      .toList();

  Map<String, dynamic>? findTrip(Object? id) => _find(trips, id);

  Map<String, dynamic>? findPickup(Object? deliveryId) {
    for (final row in pickups) {
      if (row['delivery_id'] == deliveryId) return row;
    }
    return null;
  }

  List<Map<String, dynamic>> linesFor(Object? deliveryId) =>
      lines.where((row) => row['delivery_id'] == deliveryId).toList();

  List<Map<String, dynamic>> exceptionsFor(Object? deliveryId) =>
      exceptions.where((row) => row['delivery_id'] == deliveryId).toList();

  String itemName(Object? id) => _find(items, id)?['name'] as String? ?? 'Item';

  String customerName(Map<String, dynamic> delivery) {
    final order = _find(orders, delivery['sales_order_id']);
    final customer = order == null ? null : _find(customers, order['customer_id']);
    return customer?['name'] as String? ?? 'Customer';
  }

  String customerAddress(Map<String, dynamic> delivery) {
    final order = _find(orders, delivery['sales_order_id']);
    final customer = order == null ? null : _find(customers, order['customer_id']);
    if (customer == null) return '';
    return [customer['address_line1'], customer['city'], customer['state']]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
  }

  String vehicleLabel(Map<String, dynamic>? trip) {
    final vehicle = trip == null ? null : _find(vehicles, trip['vehicle_id']);
    if (vehicle == null) return 'Vehicle';
    return '${vehicle['registration_no']} · ${vehicle['vehicle_code']}';
  }
}

class _DeliveryHero extends StatelessWidget {
  const _DeliveryHero({
    required this.data,
    required this.delivery,
    required this.trip,
  });

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
              Text(
                "TODAY'S DELIVERY",
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: FactorySpacing.xs),
              Text(
                delivery['delivery_no'] as String,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Text(
                data.customerName(delivery),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(data.customerAddress(delivery)),
              const SizedBox(height: FactorySpacing.md),
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  const SizedBox(width: FactorySpacing.xs),
                  Expanded(child: Text(data.vehicleLabel(trip))),
                  Chip(label: Text(_label(delivery['status'] as String))),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.data, required this.lines});

  final DriverDeliverySnapshot data;
  final List<Map<String, dynamic>> lines;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loaded items',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FactorySpacing.sm),
              if (lines.isEmpty)
                const Text('No delivery lines found.')
              else
                for (final line in lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(data.itemName(line['item_id'])),
                    subtitle: Text('Planned ${line['planned_quantity']}'),
                    trailing: Text(
                      '${line['delivered_quantity']} / ${line['loaded_quantity']}',
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.status,
    required this.tripStatus,
    required this.onStart,
    required this.onArrive,
    required this.onDeliver,
    required this.onCompleteTrip,
  });

  final String status;
  final String? tripStatus;
  final VoidCallback onStart;
  final VoidCallback onArrive;
  final VoidCallback onDeliver;
  final VoidCallback onCompleteTrip;

  @override
  Widget build(BuildContext context) {
    Widget action;
    if (status == 'ready_to_load') {
      action = const ListTile(
        leading: Icon(Icons.hourglass_top),
        title: Text('Waiting for vehicle load confirmation'),
        subtitle: Text('Dispatch Admin must confirm the Warehouse load first.'),
      );
    } else if (status == 'loaded') {
      action = FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.route_outlined),
        label: const Text('Start delivery'),
      );
    } else if (status == 'in_transit') {
      action = FilledButton.icon(
        onPressed: onArrive,
        icon: const Icon(Icons.location_on_outlined),
        label: const Text('Arrive at customer'),
      );
    } else if (status == 'arrived') {
      action = FilledButton.icon(
        onPressed: onDeliver,
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Complete delivery & POD'),
      );
    } else if (status == 'delivered' && tripStatus == 'arrived') {
      action = FilledButton.tonalIcon(
        onPressed: onCompleteTrip,
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Complete vehicle trip'),
      );
    } else {
      action = ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text('Delivery ${_label(status)}'),
        subtitle: tripStatus == null ? null : Text('Trip ${_label(tripStatus!)}'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: SizedBox(width: double.infinity, child: action),
      ),
    );
  }
}

class _ReturnablesCard extends StatelessWidget {
  const _ReturnablesCard({
    required this.pickup,
    required this.canAdd,
    required this.onAdd,
    required this.onClose,
  });

  final Map<String, dynamic>? pickup;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Returnables',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                pickup == null
                    ? 'No returnable pickup recorded.'
                    : 'Pickup ${_label(pickup!['status'] as String)}',
              ),
              if (canAdd) ...[
                const SizedBox(height: FactorySpacing.sm),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.recycling_outlined),
                  label: const Text('Add returnable pickup'),
                ),
              ],
              if (onClose != null)
                FilledButton.tonal(
                  onPressed: onClose,
                  child: const Text('Close returnable pickup'),
                ),
            ],
          ),
        ),
      );
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard({required this.exceptions, required this.onReport});

  final List<Map<String, dynamic>> exceptions;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Exceptions',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onReport,
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
                    leading: Icon(
                      row['status'] == 'open'
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                    ),
                    title: Text(_label(row['exception_type'] as String)),
                    subtitle: Text(row['details'] as String),
                    trailing: Text(_label(row['status'] as String)),
                  ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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

Map<String, dynamic>? _find(List<Map<String, dynamic>> rows, Object? id) {
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _safeImageExtension(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.webp')) return 'webp';
  return 'jpg';
}

String _imageContentType(String extension) => switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

String _label(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is StorageException) return error.message;
  return '$error';
}
