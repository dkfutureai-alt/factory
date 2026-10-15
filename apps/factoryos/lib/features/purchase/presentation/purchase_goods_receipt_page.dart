import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/purchase_receipt_repository.dart';
import '../domain/purchase_receipt_models.dart';

class PurchaseGoodsReceiptPage extends StatefulWidget {
  const PurchaseGoodsReceiptPage({
    super.key,
    required this.repository,
    required this.orderNumber,
  });

  final PurchaseReceiptRepository repository;
  final String orderNumber;

  @override
  State<PurchaseGoodsReceiptPage> createState() => _PurchaseGoodsReceiptPageState();
}

class _PurchaseGoodsReceiptPageState extends State<PurchaseGoodsReceiptPage> {
  final _invoiceController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, _LineInput> _lineInputs = {};

  PurchaseReceiptOptions? _options;
  Object? _loadError;
  bool _loading = true;
  bool _posting = false;
  String? _warehouseId;
  late String _requestKey;
  PurchaseReceiptResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _requestKey = _newRequestKey();
    _load();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _deliveryNoteController.dispose();
    _noteController.dispose();
    for (final input in _lineInputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  String _newRequestKey() => 'purchase-grn-${DateTime.now().microsecondsSinceEpoch}-${widget.orderNumber}';

  Future<void> _load() async {
    try {
      final options = await widget.repository.loadOptions(widget.orderNumber);
      if (!mounted) return;
      for (final line in options.lines) {
        _lineInputs.putIfAbsent(line.purchaseOrderLineId, () => _LineInput.fromOption(line));
      }
      final validIds = options.lines.map((line) => line.purchaseOrderLineId).toSet();
      final removed = _lineInputs.keys.where((id) => !validIds.contains(id)).toList(growable: false);
      for (final id in removed) {
        _lineInputs.remove(id)?.dispose();
      }
      setState(() {
        _options = options;
        _warehouseId = options.warehouses.any((item) => item.id == _warehouseId)
            ? _warehouseId
            : (options.warehouses.isEmpty ? null : options.warehouses.first.id);
        _syncLocations(options);
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  void _syncLocations(PurchaseReceiptOptions options) {
    final warehouseId = _warehouseId;
    final locations = options.locations.where((item) => item.warehouseId == warehouseId).toList(growable: false);
    for (final input in _lineInputs.values) {
      if (!locations.any((item) => item.id == input.locationId)) {
        input.locationId = locations.isEmpty ? null : locations.first.id;
      }
    }
  }

  PurchaseReceiptRequest? _buildRequest() {
    final options = _options;
    final warehouseId = _warehouseId;
    if (options == null || warehouseId == null) return null;

    final lines = <PurchaseReceiptLineRequest>[];
    for (final option in options.lines) {
      final input = _lineInputs[option.purchaseOrderLineId];
      if (input == null) continue;
      final received = input.received;
      final accepted = input.accepted;
      final rejected = input.rejected;
      if (received <= 0 && accepted <= 0 && rejected <= 0) continue;
      final locationId = input.locationId ?? '';
      final allocations = <PurchaseReceiptAllocationRequest>[];
      if (accepted > 0) {
        if (option.serialTracking) {
          for (final serial in input.serialNumbers) {
            allocations.add(PurchaseReceiptAllocationRequest(
              locationId: locationId,
              quantity: 1,
              serialNumber: serial,
            ));
          }
        } else {
          allocations.add(PurchaseReceiptAllocationRequest(
            locationId: locationId,
            quantity: accepted,
            batchNumber: option.batchTracking ? input.trackingController.text.trim() : null,
          ));
        }
      }
      lines.add(PurchaseReceiptLineRequest(
        purchaseOrderLineId: option.purchaseOrderLineId,
        receivedQuantity: received,
        acceptedQuantity: accepted,
        rejectedQuantity: rejected,
        supplierBatchNumber: option.batchTracking ? input.trackingController.text.trim() : null,
        note: input.noteController.text.trim(),
        allocations: allocations,
      ));
    }

    return PurchaseReceiptRequest(
      purchaseOrderId: options.purchaseOrderId,
      warehouseId: warehouseId,
      supplierInvoiceNumber: _invoiceController.text,
      supplierDeliveryNote: _deliveryNoteController.text,
      note: _noteController.text,
      lines: lines,
      idempotencyKey: _requestKey,
    );
  }

  Future<void> _post() async {
    final options = _options;
    if (options == null || _posting) return;
    if (!widget.repository.supportsPosting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview mode: GRN posting is disabled until the dedicated FactoryOS Supabase backend is connected.')),
      );
      return;
    }
    final request = _buildRequest();
    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a receiving warehouse.')));
      return;
    }
    final error = request.validate(options);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _posting = true);
    try {
      final result = await widget.repository.postReceipt(request);
      if (!mounted) return;
      setState(() {
        _posting = false;
        _lastResult = result;
        _requestKey = _newRequestKey();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.grnNumber} posted successfully.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goods receipt failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Purchase GRN / Goods Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('PO-linked receiving • immutable inventory ledger', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _ErrorState(onRetry: _load)
                : _content(_options!),
      );

  Widget _content(PurchaseReceiptOptions options) {
    final warehouseLocations = options.locations.where((item) => item.warehouseId == _warehouseId).toList(growable: false);
    final request = _buildRequest();
    final accepted = request?.acceptedQuantity ?? 0;
    final rejected = request?.rejectedQuantity ?? 0;
    final acceptedValue = options.lines.fold<double>(0, (sum, option) {
      final input = _lineInputs[option.purchaseOrderLineId];
      return sum + ((input?.accepted ?? 0) * option.unitPrice);
    });

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1080;
      final receiptForm = _ReceiptForm(
        options: options,
        warehouseId: _warehouseId,
        warehouseLocations: warehouseLocations,
        invoiceController: _invoiceController,
        deliveryNoteController: _deliveryNoteController,
        noteController: _noteController,
        lineInputs: _lineInputs,
        onWarehouseChanged: (value) {
          setState(() {
            _warehouseId = value;
            _syncLocations(options);
          });
        },
        onChanged: () => setState(() {}),
      );
      final review = _ReceiptReview(
        acceptedQuantity: accepted,
        rejectedQuantity: rejected,
        acceptedValue: acceptedValue,
        supportsPosting: widget.repository.supportsPosting,
        posting: _posting,
        result: _lastResult,
        onPost: _post,
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: receiptForm), const SizedBox(width: 20), Expanded(flex: 3, child: review)])
            : Column(children: [receiptForm, const SizedBox(height: 20), review]),
      );
    });
  }
}

class _ReceiptForm extends StatelessWidget {
  const _ReceiptForm({
    required this.options,
    required this.warehouseId,
    required this.warehouseLocations,
    required this.invoiceController,
    required this.deliveryNoteController,
    required this.noteController,
    required this.lineInputs,
    required this.onWarehouseChanged,
    required this.onChanged,
  });

  final PurchaseReceiptOptions options;
  final String? warehouseId;
  final List<PurchaseReceiptLocationOption> warehouseLocations;
  final TextEditingController invoiceController;
  final TextEditingController deliveryNoteController;
  final TextEditingController noteController;
  final Map<String, _LineInput> lineInputs;
  final ValueChanged<String?> onWarehouseChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${options.orderNumber} • ${options.supplier}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Status: ${options.status.replaceAll('_', ' ')}', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: warehouseId,
              decoration: const InputDecoration(labelText: 'Receiving warehouse'),
              items: options.warehouses.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.code} • ${item.name}'))).toList(growable: false),
              onChanged: onWarehouseChanged,
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: invoiceController, decoration: const InputDecoration(labelText: 'Supplier invoice'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: deliveryNoteController, decoration: const InputDecoration(labelText: 'Delivery note'))),
            ]),
            const SizedBox(height: 22),
            Text('Receive PO lines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (options.lines.isEmpty)
              const _Notice(text: 'This purchase order has no pending quantity to receive.')
            else
              ...options.lines.map((option) {
                final input = lineInputs[option.purchaseOrderLineId]!;
                return _LineCard(
                  option: option,
                  input: input,
                  locations: warehouseLocations,
                  onChanged: onChanged,
                );
              }),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Receiving note', hintText: 'Inspection, damage or supplier-delivery notes'),
            ),
          ]),
        ),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.option, required this.input, required this.locations, required this.onChanged});
  final PurchaseReceiptLineOption option;
  final _LineInput input;
  final List<PurchaseReceiptLocationOption> locations;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${option.sku} • ${option.itemName}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Pending ${_qty(option.pendingQuantity)} ${option.unit} • ₹${option.unitPrice.toStringAsFixed(2)} / ${option.unit}', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NumberField(label: 'Received', controller: input.receivedController, onChanged: onChanged)),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(label: 'Accepted', controller: input.acceptedController, onChanged: onChanged)),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(label: 'Rejected', controller: input.rejectedController, onChanged: onChanged)),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: locations.any((item) => item.id == input.locationId) ? input.locationId : null,
            decoration: const InputDecoration(labelText: 'Inventory location'),
            items: locations.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.code} • ${item.name}'))).toList(growable: false),
            onChanged: (value) {
              input.locationId = value;
              onChanged();
            },
          ),
          if (option.batchTracking) ...[
            const SizedBox(height: 12),
            TextField(controller: input.trackingController, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Batch number', hintText: 'Supplier/manufacturer batch')),
          ],
          if (option.serialTracking) ...[
            const SizedBox(height: 12),
            TextField(controller: input.trackingController, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Serial numbers', hintText: 'Comma-separated, one serial per accepted unit')),
          ],
          const SizedBox(height: 12),
          TextField(controller: input.noteController, decoration: const InputDecoration(labelText: 'Line note')),
        ]),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, required this.onChanged});
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label),
      );
}

class _ReceiptReview extends StatelessWidget {
  const _ReceiptReview({
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    required this.acceptedValue,
    required this.supportsPosting,
    required this.posting,
    required this.result,
    required this.onPost,
  });
  final double acceptedQuantity;
  final double rejectedQuantity;
  final double acceptedValue;
  final bool supportsPosting;
  final bool posting;
  final PurchaseReceiptResult? result;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Review & post', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _Metric(label: 'Accepted to inventory', value: _qty(acceptedQuantity)),
            _Metric(label: 'Rejected / no stock effect', value: _qty(rejectedQuantity)),
            _Metric(label: 'Accepted value', value: '₹${acceptedValue.toStringAsFixed(2)}'),
            const Divider(height: 32),
            const _Check(text: 'PO must be approved and open'),
            const _Check(text: 'Warehouse and location are scope checked'),
            const _Check(text: 'Accepted + rejected = received'),
            const _Check(text: 'Batch / serial tracking is enforced'),
            const _Check(text: 'Accepted stock posts through one immutable ledger transaction'),
            const _Check(text: 'Idempotent retry protection is enabled'),
            if (!supportsPosting) ...[
              const SizedBox(height: 14),
              const _Notice(text: 'Preview mode is read-only. No GRN or stock mutation will be simulated.'),
            ],
            if (result != null) ...[
              const SizedBox(height: 14),
              _Notice(text: '${result!.grnNumber} • ${result!.status}'),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('post-purchase-grn'),
              onPressed: posting ? null : onPost,
              icon: posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.inventory_2_outlined),
              label: Text(posting ? 'Posting…' : 'Post goods receipt'),
            ),
          ]),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: AppTheme.muted)),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Could not load Purchase GRN options.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

class _LineInput {
  _LineInput({required double pending})
      : receivedController = TextEditingController(text: _qty(pending)),
        acceptedController = TextEditingController(text: _qty(pending)),
        rejectedController = TextEditingController(text: '0');

  factory _LineInput.fromOption(PurchaseReceiptLineOption option) => _LineInput(pending: option.pendingQuantity);

  final TextEditingController receivedController;
  final TextEditingController acceptedController;
  final TextEditingController rejectedController;
  final TextEditingController trackingController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String? locationId;

  double get received => double.tryParse(receivedController.text.trim()) ?? 0;
  double get accepted => double.tryParse(acceptedController.text.trim()) ?? 0;
  double get rejected => double.tryParse(rejectedController.text.trim()) ?? 0;
  List<String> get serialNumbers => trackingController.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  void dispose() {
    receivedController.dispose();
    acceptedController.dispose();
    rejectedController.dispose();
    trackingController.dispose();
    noteController.dispose();
  }
}

String _qty(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
