import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

class InventoryNameCodeEditor extends StatefulWidget {
  const InventoryNameCodeEditor({
    required this.title,
    this.initial,
    this.unitMode = false,
    super.key,
  });

  final String title;
  final Map<String, dynamic>? initial;
  final bool unitMode;

  @override
  State<InventoryNameCodeEditor> createState() =>
      _InventoryNameCodeEditorState();
}

class _InventoryNameCodeEditorState extends State<InventoryNameCodeEditor> {
  late final name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final code = TextEditingController(
    text: widget.initial?['code'] as String? ?? '',
  );
  late final decimals = TextEditingController(
    text: '${widget.initial?['decimal_places'] ?? 2}',
  );

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    decimals.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) return;
    Navigator.pop(context, {
      'name': name.text.trim(),
      'code': code.text.trim().toUpperCase(),
      if (widget.unitMode) 'decimal_places': int.tryParse(decimals.text) ?? 2,
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          if (widget.unitMode) ...[
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: decimals,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Decimal places'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}

class InventoryItemEditor extends StatefulWidget {
  const InventoryItemEditor({
    required this.categories,
    required this.units,
    this.initial,
    super.key,
  });
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final Map<String, dynamic>? initial;

  @override
  State<InventoryItemEditor> createState() => _InventoryItemEditorState();
}

class _InventoryItemEditorState extends State<InventoryItemEditor> {
  late final name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final sku = TextEditingController(
    text: widget.initial?['sku'] as String? ?? '',
  );
  late final barcode = TextEditingController(
    text: widget.initial?['barcode'] as String? ?? '',
  );
  late final qr = TextEditingController(
    text: widget.initial?['qr_code'] as String? ?? '',
  );
  late final notes = TextEditingController(
    text: widget.initial?['notes'] as String? ?? '',
  );
  late String? categoryId = widget.initial?['category_id'] as String?;
  late String? unitId =
      widget.initial?['unit_id'] as String? ??
      (widget.units.isEmpty ? null : widget.units.first['id'] as String);
  late String itemType =
      widget.initial?['item_type'] as String? ?? 'raw_material';
  late bool batchTracked =
      widget.initial?['is_batch_tracked'] as bool? ?? false;

  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    barcode.dispose();
    qr.dispose();
    notes.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().length < 2 ||
        sku.text.trim().length < 2 ||
        unitId == null) {
      return;
    }
    Navigator.pop(context, {
      'name': name.text.trim(),
      'sku': sku.text.trim().toUpperCase(),
      'category_id': categoryId,
      'unit_id': unitId,
      'item_type': itemType,
      'barcode': _blank(barcode.text),
      'qr_code': _blank(qr.text),
      'is_batch_tracked': batchTracked,
      'notes': _blank(notes.text),
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add item' : 'Edit item'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: sku,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorized'),
                ),
                ...widget.categories.map(
                  (row) => DropdownMenuItem<String?>(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => categoryId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: unitId,
              decoration: const InputDecoration(labelText: 'Base unit'),
              items: widget.units
                  .map(
                    (row) => DropdownMenuItem<String>(
                      value: row['id'] as String,
                      child: Text('${row['name']} (${row['code']})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => unitId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: itemType,
              decoration: const InputDecoration(labelText: 'Item type'),
              items:
                  const [
                        'raw_material',
                        'consumable',
                        'finished_good',
                        'spare',
                        'packaging',
                        'gas',
                        'cylinder',
                        'other',
                      ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_title(value)),
                        ),
                      )
                      .toList(),
              onChanged: (value) =>
                  setState(() => itemType = value ?? itemType),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: barcode,
              decoration: const InputDecoration(
                labelText: 'Barcode / EAN / Code 128',
              ),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: qr,
              decoration: const InputDecoration(labelText: 'QR code value'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Batch tracked'),
              value: batchTracked,
              onChanged: (value) => setState(() => batchTracked = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}

class StockLocationEditor extends StatefulWidget {
  const StockLocationEditor({required this.factories, this.initial, super.key});
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;

  @override
  State<StockLocationEditor> createState() => _StockLocationEditorState();
}

class _StockLocationEditorState extends State<StockLocationEditor> {
  late final name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final code = TextEditingController(
    text: widget.initial?['code'] as String? ?? '',
  );
  late String? factoryId =
      widget.initial?['factory_id'] as String? ??
      (widget.factories.isEmpty
          ? null
          : widget.factories.first['id'] as String);
  late String locationType =
      widget.initial?['location_type'] as String? ?? 'warehouse';

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  void save() {
    if (factoryId == null ||
        name.text.trim().length < 2 ||
        code.text.trim().length < 2) {
      return;
    }
    Navigator.pop(context, {
      'factory_id': factoryId,
      'name': name.text.trim(),
      'code': code.text.trim().toUpperCase(),
      'location_type': locationType,
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Add stock location' : 'Edit stock location',
    ),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: factoryId,
            decoration: const InputDecoration(labelText: 'Factory'),
            items: widget.factories
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                )
                .toList(),
            onChanged: widget.initial == null
                ? (value) => setState(() => factoryId = value)
                : null,
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Location name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: locationType,
            decoration: const InputDecoration(labelText: 'Location type'),
            items:
                const [
                      'warehouse',
                      'bin',
                      'production',
                      'quality',
                      'dispatch',
                      'vehicle',
                      'quarantine',
                      'other',
                    ]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_title(value)),
                      ),
                    )
                    .toList(),
            onChanged: (value) =>
                setState(() => locationType = value ?? locationType),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}

class ReorderRuleEditor extends StatefulWidget {
  const ReorderRuleEditor({
    required this.factories,
    required this.items,
    this.initial,
    super.key,
  });
  final List<Map<String, dynamic>> factories;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;

  @override
  State<ReorderRuleEditor> createState() => _ReorderRuleEditorState();
}

class _ReorderRuleEditorState extends State<ReorderRuleEditor> {
  late String? factoryId =
      widget.initial?['factory_id'] as String? ??
      (widget.factories.isEmpty
          ? null
          : widget.factories.first['id'] as String);
  late String? itemId =
      widget.initial?['item_id'] as String? ??
      (widget.items.isEmpty ? null : widget.items.first['id'] as String);
  late final level = TextEditingController(
    text: '${widget.initial?['reorder_level'] ?? 0}',
  );
  late final quantity = TextEditingController(
    text: '${widget.initial?['reorder_quantity'] ?? 0}',
  );

  @override
  void dispose() {
    level.dispose();
    quantity.dispose();
    super.dispose();
  }

  void save() {
    if (factoryId == null || itemId == null) return;
    Navigator.pop(context, {
      'factory_id': factoryId,
      'item_id': itemId,
      'reorder_level': double.tryParse(level.text) ?? 0,
      'reorder_quantity': double.tryParse(quantity.text) ?? 0,
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Add reorder rule' : 'Edit reorder rule',
    ),
    content: SizedBox(
      width: 540,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: factoryId,
            decoration: const InputDecoration(labelText: 'Factory'),
            items: widget.factories
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                )
                .toList(),
            onChanged: widget.initial == null
                ? (value) => setState(() => factoryId = value)
                : null,
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: itemId,
            decoration: const InputDecoration(labelText: 'Item'),
            items: widget.items
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text('${row['name']} · ${row['sku']}'),
                  ),
                )
                .toList(),
            onChanged: widget.initial == null
                ? (value) => setState(() => itemId = value)
                : null,
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: level,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Reorder level'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Suggested reorder quantity',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}

class StockMovementDraft {
  const StockMovementDraft({
    required this.type,
    required this.factoryId,
    required this.itemId,
    required this.quantity,
    this.fromLocationId,
    this.toLocationId,
    this.unitCost,
    this.reference,
    this.notes,
  });
  final String type;
  final String factoryId;
  final String itemId;
  final double quantity;
  final String? fromLocationId;
  final String? toLocationId;
  final double? unitCost;
  final String? reference;
  final String? notes;
}

class StockMovementEditor extends StatefulWidget {
  const StockMovementEditor({
    required this.type,
    required this.factories,
    required this.items,
    required this.locations,
    super.key,
  });
  final String type;
  final List<Map<String, dynamic>> factories;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;

  @override
  State<StockMovementEditor> createState() => _StockMovementEditorState();
}

class _StockMovementEditorState extends State<StockMovementEditor> {
  late String? factoryId = widget.factories.isEmpty
      ? null
      : widget.factories.first['id'] as String;
  late String? itemId = widget.items.isEmpty
      ? null
      : widget.items.first['id'] as String;
  String? fromLocationId;
  String? toLocationId;
  final quantity = TextEditingController();
  final unitCost = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();

  List<Map<String, dynamic>> get scopedLocations => widget.locations
      .where(
        (row) => row['factory_id'] == factoryId && row['is_active'] != false,
      )
      .toList();

  @override
  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  void factoryChanged(String? value) {
    setState(() {
      factoryId = value;
      fromLocationId = null;
      toLocationId = null;
    });
  }

  void save() {
    final qty = double.tryParse(quantity.text);
    if (factoryId == null || itemId == null || qty == null || qty <= 0) return;
    if (widget.type == 'receive' && toLocationId == null) return;
    if (widget.type == 'issue' && fromLocationId == null) return;
    if (widget.type == 'transfer' &&
        (fromLocationId == null ||
            toLocationId == null ||
            fromLocationId == toLocationId)) {
      return;
    }
    Navigator.pop(
      context,
      StockMovementDraft(
        type: widget.type,
        factoryId: factoryId!,
        itemId: itemId!,
        quantity: qty,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        unitCost: widget.type == 'receive'
            ? double.tryParse(unitCost.text)
            : null,
        reference: _blank(reference.text),
        notes: _blank(notes.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = scopedLocations;
    return AlertDialog(
      title: Text('${_title(widget.type)} stock'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: factoryId,
                decoration: const InputDecoration(labelText: 'Factory'),
                items: widget.factories
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text(row['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: factoryChanged,
              ),
              const SizedBox(height: FactorySpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: itemId,
                decoration: const InputDecoration(labelText: 'Item'),
                items: widget.items
                    .where((row) => row['is_active'] != false)
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['sku']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => itemId = value),
              ),
              if (widget.type != 'receive') ...[
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: fromLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Source location',
                  ),
                  items: locations
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text(row['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => fromLocationId = value),
                ),
              ],
              if (widget.type != 'issue') ...[
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: toLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Destination location',
                  ),
                  items: locations
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text(row['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => toLocationId = value),
                ),
              ],
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              if (widget.type == 'receive') ...[
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: unitCost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Unit cost (optional)',
                  ),
                ),
              ],
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Reference / GRN / job / request',
                ),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: save, child: Text(_title(widget.type))),
      ],
    );
  }
}

String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
String _title(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
