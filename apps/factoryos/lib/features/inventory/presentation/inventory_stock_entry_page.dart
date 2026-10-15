import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/inventory_stock_entry_repository.dart';
import '../domain/inventory_stock_entry_models.dart';

class InventoryStockEntryPage extends StatefulWidget {
  const InventoryStockEntryPage({super.key, required this.repository});

  final InventoryStockEntryRepository repository;

  @override
  State<InventoryStockEntryPage> createState() => _InventoryStockEntryPageState();
}

class _InventoryStockEntryPageState extends State<InventoryStockEntryPage> {
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _reasonController = TextEditingController();

  InventoryStockEntryOptions? _options;
  Object? _loadError;
  bool _loading = true;
  bool _posting = false;
  InventoryStockEntryDirection _direction = InventoryStockEntryDirection.stockIn;
  String? _itemId;
  String? _warehouseId;
  String? _locationId;
  String? _batchId;
  String? _serialNumberId;
  InventoryStockEntryResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final data = await widget.repository.loadOptions();
      if (!mounted) return;
      setState(() {
        _options = data;
        _loadError = null;
        _loading = false;
        _itemId = _validOrFirst(_itemId, data.items.map((item) => item.id));
        _warehouseId = _validOrFirst(_warehouseId, data.warehouses.map((warehouse) => warehouse.id));
        final locations = data.locationsForWarehouse(_warehouseId);
        _locationId = _validOrFirst(_locationId, locations.map((location) => location.id));
        _syncTrackingSelection(data);
        _syncUnitCost(data);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  String? _validOrFirst(String? current, Iterable<String> values) {
    final list = values.toList(growable: false);
    if (current != null && list.contains(current)) return current;
    return list.isEmpty ? null : list.first;
  }

  void _syncTrackingSelection(InventoryStockEntryOptions data) {
    final item = data.itemById(_itemId);
    if (item == null) {
      _batchId = null;
      _serialNumberId = null;
      return;
    }
    if (!item.batchTracking) {
      _batchId = null;
    } else {
      final validBatches = data.batchesForItem(item.id).map((batch) => batch.id).toList(growable: false);
      if (_batchId != null && !validBatches.contains(_batchId)) _batchId = null;
    }
    if (!item.serialTracking) {
      _serialNumberId = null;
    } else {
      final validSerials = _serialOptions(data).map((serial) => serial.id).toList(growable: false);
      if (_serialNumberId != null && !validSerials.contains(_serialNumberId)) _serialNumberId = null;
    }
  }

  void _syncUnitCost(InventoryStockEntryOptions data) {
    final item = data.itemById(_itemId);
    if (item == null) return;
    _unitCostController.text = item.defaultUnitCost.toStringAsFixed(2);
  }

  List<InventoryStockEntrySerialOption> _serialOptions(InventoryStockEntryOptions data) {
    final serials = data.serialsForItem(_itemId);
    if (_direction == InventoryStockEntryDirection.stockOut) {
      return serials.where((serial) => serial.currentWarehouseId == _warehouseId).toList(growable: false);
    }
    return serials.where((serial) => serial.currentWarehouseId == null).toList(growable: false);
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;
  double? get _unitCost {
    final value = _unitCostController.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  InventoryStockEntryRequest? _buildRequest() {
    final itemId = _itemId;
    final warehouseId = _warehouseId;
    if (itemId == null || warehouseId == null) return null;
    return InventoryStockEntryRequest(
      direction: _direction,
      warehouseId: warehouseId,
      locationId: _locationId,
      itemId: itemId,
      batchId: _batchId,
      serialNumberId: _serialNumberId,
      quantity: _quantity,
      unitCost: _unitCost,
      reason: _reasonController.text,
      idempotencyKey: 'stock-entry-${DateTime.now().microsecondsSinceEpoch}-$itemId',
    );
  }

  String? _validationError(InventoryStockEntryOptions data, InventoryStockEntryRequest? request) {
    if (request == null) return 'Select an item and warehouse.';
    final error = request.validate(data);
    if (error != null) return error;
    final current = data.quantityAt(
      itemId: request.itemId,
      warehouseId: request.warehouseId,
      locationId: request.locationId,
      batchId: request.batchId,
      serialNumberId: request.serialNumberId,
    );
    if (current + request.quantityDelta < 0) return 'Stock Out would make this warehouse/location balance negative.';
    return null;
  }

  Future<void> _post() async {
    final data = _options;
    if (data == null || _posting) return;
    if (!widget.repository.supportsPosting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview mode: connect the dedicated FactoryOS Supabase backend to post stock.')),
      );
      return;
    }
    final request = _buildRequest();
    final error = _validationError(data, request);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _posting = true);
    try {
      final result = await widget.repository.postAdjustment(request!);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _posting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.transactionNumber} posted successfully.')),
      );
      await _loadOptions();
    } catch (error) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock entry failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Stock Entry', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Ledger-controlled manual adjustment', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _LoadError(onRetry: _loadOptions)
                : _buildContent(context, _options!),
      );

  Widget _buildContent(BuildContext context, InventoryStockEntryOptions data) {
    final item = data.itemById(_itemId);
    final locations = data.locationsForWarehouse(_warehouseId);
    final batches = data.batchesForItem(_itemId);
    final serials = _serialOptions(data);
    final current = data.quantityAt(
      itemId: _itemId,
      warehouseId: _warehouseId,
      locationId: _locationId,
      batchId: _batchId,
      serialNumberId: _serialNumberId,
    );
    final delta = _direction.signedQuantity(_quantity);
    final projected = current + delta;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final form = _EntryForm(
          direction: _direction,
          item: item,
          items: data.items,
          warehouses: data.warehouses,
          locations: locations,
          batches: batches,
          serials: serials,
          selectedItemId: _itemId,
          selectedWarehouseId: _warehouseId,
          selectedLocationId: _locationId,
          selectedBatchId: _batchId,
          selectedSerialId: _serialNumberId,
          quantityController: _quantityController,
          unitCostController: _unitCostController,
          reasonController: _reasonController,
          onDirectionChanged: (direction) {
            setState(() {
              _direction = direction;
              _serialNumberId = null;
              _syncTrackingSelection(data);
            });
          },
          onItemChanged: (value) {
            setState(() {
              _itemId = value;
              _batchId = null;
              _serialNumberId = null;
              _syncTrackingSelection(data);
              _syncUnitCost(data);
            });
          },
          onWarehouseChanged: (value) {
            setState(() {
              _warehouseId = value;
              final nextLocations = data.locationsForWarehouse(value);
              _locationId = nextLocations.isEmpty ? null : nextLocations.first.id;
              _serialNumberId = null;
              _syncTrackingSelection(data);
            });
          },
          onLocationChanged: (value) => setState(() => _locationId = value),
          onBatchChanged: (value) => setState(() => _batchId = value),
          onSerialChanged: (value) => setState(() => _serialNumberId = value),
          onInputChanged: () => setState(() {}),
        );
        final review = _ReviewCard(
          item: item,
          current: current,
          delta: delta,
          projected: projected,
          postingSupported: widget.repository.supportsPosting,
          posting: _posting,
          result: _lastResult,
          onPost: _post,
        );

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!widget.repository.supportsPosting) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Preview mode — this screen is interactive, but posting is disabled until the dedicated FactoryOS Supabase backend is connected.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: form),
                  const SizedBox(width: 18),
                  Expanded(flex: 4, child: review),
                ],
              )
            else ...[
              form,
              const SizedBox(height: 18),
              review,
            ],
            const SizedBox(height: 18),
            const Text(
              'Manual adjustment only. Purchase receipts, Production movements, Warehouse transfers, Dispatch, Returns and Maintenance keep their dedicated transactional workflows.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
          ],
        );
      },
    );
  }
}

class _EntryForm extends StatelessWidget {
  const _EntryForm({
    required this.direction,
    required this.item,
    required this.items,
    required this.warehouses,
    required this.locations,
    required this.batches,
    required this.serials,
    required this.selectedItemId,
    required this.selectedWarehouseId,
    required this.selectedLocationId,
    required this.selectedBatchId,
    required this.selectedSerialId,
    required this.quantityController,
    required this.unitCostController,
    required this.reasonController,
    required this.onDirectionChanged,
    required this.onItemChanged,
    required this.onWarehouseChanged,
    required this.onLocationChanged,
    required this.onBatchChanged,
    required this.onSerialChanged,
    required this.onInputChanged,
  });

  final InventoryStockEntryDirection direction;
  final InventoryStockEntryItemOption? item;
  final List<InventoryStockEntryItemOption> items;
  final List<InventoryStockEntryWarehouseOption> warehouses;
  final List<InventoryStockEntryLocationOption> locations;
  final List<InventoryStockEntryBatchOption> batches;
  final List<InventoryStockEntrySerialOption> serials;
  final String? selectedItemId;
  final String? selectedWarehouseId;
  final String? selectedLocationId;
  final String? selectedBatchId;
  final String? selectedSerialId;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController reasonController;
  final ValueChanged<InventoryStockEntryDirection> onDirectionChanged;
  final ValueChanged<String?> onItemChanged;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onBatchChanged;
  final ValueChanged<String?> onSerialChanged;
  final VoidCallback onInputChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Entry details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              const Text('Entry type', style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<InventoryStockEntryDirection>(
                segments: const [
                  ButtonSegment(value: InventoryStockEntryDirection.stockIn, label: Text('Stock In'), icon: Icon(Icons.add_circle_outline)),
                  ButtonSegment(value: InventoryStockEntryDirection.stockOut, label: Text('Stock Out'), icon: Icon(Icons.remove_circle_outline)),
                ],
                selected: {direction},
                onSelectionChanged: (values) => onDirectionChanged(values.first),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedItemId,
                decoration: const InputDecoration(labelText: 'Item'),
                items: items
                    .map((item) => DropdownMenuItem(value: item.id, child: Text('${item.sku} • ${item.name}', overflow: TextOverflow.ellipsis)))
                    .toList(growable: false),
                onChanged: onItemChanged,
              ),
              if (item != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${item!.unit} • ${item!.totalOnHand.toStringAsFixed(2)} total on hand${item!.batchTracking ? ' • batch tracked' : item!.serialTracking ? ' • serial tracked' : ''}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedWarehouseId,
                      decoration: const InputDecoration(labelText: 'Warehouse'),
                      items: warehouses
                          .map((warehouse) => DropdownMenuItem(value: warehouse.id, child: Text('${warehouse.code} • ${warehouse.name}', overflow: TextOverflow.ellipsis)))
                          .toList(growable: false),
                      onChanged: onWarehouseChanged,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedLocationId,
                      decoration: const InputDecoration(labelText: 'Location'),
                      items: locations
                          .map((location) => DropdownMenuItem(value: location.id, child: Text('${location.code} • ${location.name}', overflow: TextOverflow.ellipsis)))
                          .toList(growable: false),
                      onChanged: onLocationChanged,
                    ),
                  ),
                ],
              ),
              if (item?.batchTracking == true) ...[
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedBatchId,
                  decoration: const InputDecoration(labelText: 'Batch • required'),
                  items: batches
                      .map((batch) => DropdownMenuItem(value: batch.id, child: Text(batch.batchNumber)))
                      .toList(growable: false),
                  onChanged: onBatchChanged,
                ),
              ],
              if (item?.serialTracking == true) ...[
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedSerialId,
                  decoration: const InputDecoration(labelText: 'Serial number • required'),
                  items: serials
                      .map((serial) => DropdownMenuItem(value: serial.id, child: Text('${serial.serialNumber} • ${serial.status}')))
                      .toList(growable: false),
                  onChanged: onSerialChanged,
                ),
                if (serials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No eligible serial numbers for this direction and warehouse.', style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                  ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Quantity${item == null ? '' : ' • ${item!.unit}'}'),
                      onChanged: (_) => onInputChanged(),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: unitCostController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Unit cost'),
                      onChanged: (_) => onInputChanged(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Reason • required', hintText: 'Example: Approved physical count correction'),
                onChanged: (_) => onInputChanged(),
              ),
            ],
          ),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.current,
    required this.delta,
    required this.projected,
    required this.postingSupported,
    required this.posting,
    required this.result,
    required this.onPost,
  });

  final InventoryStockEntryItemOption? item;
  final double current;
  final double delta;
  final double projected;
  final bool postingSupported;
  final bool posting;
  final InventoryStockEntryResult? result;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final unit = item?.unit ?? '';
    final negative = projected < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review before posting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 22),
            _ReviewMetric(label: 'Current at location', value: '${current.toStringAsFixed(2)} $unit'),
            _ReviewMetric(
              label: 'Entry delta',
              value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} $unit',
              color: delta < 0 ? AppTheme.warning : AppTheme.success,
            ),
            _ReviewMetric(
              label: 'Projected stock',
              value: '${projected.toStringAsFixed(2)} $unit',
              color: negative ? AppTheme.danger : AppTheme.primary,
            ),
            const Divider(height: 32),
            const _Gate(text: 'Immutable adjustment ledger transaction'),
            const _Gate(text: 'Exact warehouse permission required'),
            const _Gate(text: 'Batch / serial tracking enforced'),
            const _Gate(text: 'Authenticated actor + reason audited'),
            _Gate(text: negative ? 'Negative projected stock — posting blocked' : 'Projected stock remains valid', danger: negative),
            if (result != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${result!.transactionNumber} • ${result!.status.toUpperCase()}',
                  style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: posting ? null : onPost,
                icon: posting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.post_add),
                label: Text(posting ? 'Posting…' : 'Post stock entry'),
              ),
            ),
            if (!postingSupported) ...[
              const SizedBox(height: 10),
              const Text('Preview mode does not write stock.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({required this.label, required this.value, this.color = AppTheme.text});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _Gate extends StatelessWidget {
  const _Gate({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(danger ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: danger ? AppTheme.danger : AppTheme.success),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: danger ? AppTheme.danger : AppTheme.text, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 38, color: AppTheme.danger),
            const SizedBox(height: 12),
            const Text('Unable to load Stock Entry options.', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
