import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

class RecipeEditor extends StatefulWidget {
  const RecipeEditor({required this.items, this.initial, super.key});
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;

  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  late final TextEditingController name;
  late final TextEditingController version;
  late final TextEditingController outputQty;
  late final TextEditingController notes;
  String? productItemId;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    version = TextEditingController(
      text: widget.initial?['version'] as String? ?? 'V1',
    );
    outputQty = TextEditingController(
      text: '${widget.initial?['output_quantity'] ?? 1}',
    );
    notes = TextEditingController(
      text: widget.initial?['notes'] as String? ?? '',
    );
    productItemId = widget.initial?['product_item_id'] as String?;
  }

  @override
  void dispose() {
    name.dispose();
    version.dispose();
    outputQty.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final qty = num.tryParse(outputQty.text.trim());
    if (productItemId == null ||
        name.text.trim().length < 2 ||
        version.text.trim().isEmpty ||
        qty == null ||
        qty <= 0)
      return;
    Navigator.pop(context, {
      'product_item_id': productItemId,
      'name': name.text.trim(),
      'version': version.text.trim(),
      'output_quantity': qty,
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Add recipe / BOM' : 'Edit recipe / BOM',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: productItemId,
              decoration: const InputDecoration(labelText: 'Output product'),
              items: widget.items
                  .where((row) => row['is_active'] == true)
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['name']} · ${row['sku']}'),
                    ),
                  )
                  .toList(),
              onChanged: widget.initial == null
                  ? (value) => setState(() => productItemId = value)
                  : null,
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Recipe / BOM name'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: version,
                    decoration: const InputDecoration(labelText: 'Version'),
                  ),
                ),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: TextField(
                    controller: outputQty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Output quantity',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: notes,
              maxLines: 3,
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
      FilledButton(onPressed: submit, child: const Text('Save')),
    ],
  );
}

class RecipeComponentEditor extends StatefulWidget {
  const RecipeComponentEditor({required this.items, super.key});
  final List<Map<String, dynamic>> items;

  @override
  State<RecipeComponentEditor> createState() => _RecipeComponentEditorState();
}

class _RecipeComponentEditorState extends State<RecipeComponentEditor> {
  String? itemId;
  final quantity = TextEditingController(text: '1');
  final scrap = TextEditingController(text: '0');
  final notes = TextEditingController();

  @override
  void dispose() {
    quantity.dispose();
    scrap.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final qty = num.tryParse(quantity.text.trim());
    final pct = num.tryParse(scrap.text.trim());
    if (itemId == null ||
        qty == null ||
        qty <= 0 ||
        pct == null ||
        pct < 0 ||
        pct > 100)
      return;
    Navigator.pop(context, {
      'item_id': itemId,
      'quantity_required': qty,
      'scrap_allowance_pct': pct,
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add BOM component'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: itemId,
            decoration: const InputDecoration(
              labelText: 'Material / component',
            ),
            items: widget.items
                .where((row) => row['is_active'] == true)
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text('${row['name']} · ${row['sku']}'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => itemId = value),
          ),
          const SizedBox(height: FactorySpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity required',
                  ),
                ),
              ),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: TextField(
                  controller: scrap,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Scrap allowance %',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Add')),
    ],
  );
}

class WorkCenterEditor extends StatefulWidget {
  const WorkCenterEditor({required this.factories, this.initial, super.key});
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;

  @override
  State<WorkCenterEditor> createState() => _WorkCenterEditorState();
}

class _WorkCenterEditorState extends State<WorkCenterEditor> {
  String? factoryId;
  String type = 'line';
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController capacity;
  late final TextEditingController notes;

  @override
  void initState() {
    super.initState();
    factoryId =
        widget.initial?['factory_id'] as String? ??
        (widget.factories.isEmpty
            ? null
            : widget.factories.first['id'] as String);
    type = widget.initial?['center_type'] as String? ?? 'line';
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
    capacity = TextEditingController(
      text: widget.initial?['capacity_per_hour'] == null
          ? ''
          : '${widget.initial!['capacity_per_hour']}',
    );
    notes = TextEditingController(
      text: widget.initial?['notes'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    capacity.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final cap = capacity.text.trim().isEmpty
        ? null
        : num.tryParse(capacity.text.trim());
    if (factoryId == null ||
        name.text.trim().length < 2 ||
        code.text.trim().length < 2 ||
        (capacity.text.trim().isNotEmpty && (cap == null || cap <= 0)))
      return;
    Navigator.pop(context, {
      'factory_id': factoryId,
      'name': name.text.trim(),
      'code': code.text.trim().toUpperCase().replaceAll(' ', '-'),
      'center_type': type,
      'capacity_per_hour': cap,
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      'is_active': widget.initial?['is_active'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Add work center' : 'Edit work center',
    ),
    content: SizedBox(
      width: 520,
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
                      child: Text('${row['name']} · ${row['code']}'),
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
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const ['machine', 'line', 'station', 'area', 'other']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => type = value ?? type),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: capacity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Capacity / hour (optional)',
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
      FilledButton(onPressed: submit, child: const Text('Save')),
    ],
  );
}

class ProductionOrderEditor extends StatefulWidget {
  const ProductionOrderEditor({
    required this.factories,
    required this.recipes,
    required this.workCenters,
    super.key,
  });
  final List<Map<String, dynamic>> factories;
  final List<Map<String, dynamic>> recipes;
  final List<Map<String, dynamic>> workCenters;

  @override
  State<ProductionOrderEditor> createState() => _ProductionOrderEditorState();
}

class _ProductionOrderEditorState extends State<ProductionOrderEditor> {
  String? factoryId;
  String? recipeId;
  String? workCenterId;
  String priority = 'normal';
  final quantity = TextEditingController(text: '100');
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    factoryId = widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
    final centers = _centers;
    workCenterId = centers.isEmpty ? null : centers.first['id'] as String;
    recipeId = widget.recipes.isEmpty
        ? null
        : widget.recipes.first['id'] as String;
  }

  List<Map<String, dynamic>> get _centers => widget.workCenters
      .where(
        (row) => row['factory_id'] == factoryId && row['is_active'] == true,
      )
      .toList();

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final qty = num.tryParse(quantity.text.trim());
    if (factoryId == null ||
        recipeId == null ||
        workCenterId == null ||
        qty == null ||
        qty <= 0)
      return;
    Navigator.pop(context, {
      'factory_id': factoryId,
      'recipe_id': recipeId,
      'work_center_id': workCenterId,
      'planned_quantity': qty,
      'priority': priority,
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create production order'),
    content: SizedBox(
      width: 540,
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
              onChanged: (value) => setState(() {
                factoryId = value;
                final centers = _centers;
                workCenterId = centers.isEmpty
                    ? null
                    : centers.first['id'] as String;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: recipeId,
              decoration: const InputDecoration(labelText: 'Product / recipe'),
              items: widget.recipes
                  .where((row) => row['is_active'] == true)
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['name']} · ${row['version']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => recipeId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: workCenterId,
              decoration: const InputDecoration(labelText: 'Work center'),
              items: _centers
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['name']} · ${row['code']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => workCenterId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Planned quantity'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const ['low', 'normal', 'high', 'urgent']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => priority = value ?? priority),
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
      FilledButton(onPressed: submit, child: const Text('Create')),
    ],
  );
}

class StartBatchEditor extends StatefulWidget {
  const StartBatchEditor({
    required this.orders,
    required this.shifts,
    required this.employees,
    super.key,
  });
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> employees;

  @override
  State<StartBatchEditor> createState() => _StartBatchEditorState();
}

class _StartBatchEditorState extends State<StartBatchEditor> {
  String? orderId;
  String? shiftId;
  String? operatorId;
  final batchNo = TextEditingController(text: 'BATCH-');
  final quantity = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    orderId = widget.orders.isEmpty
        ? null
        : widget.orders.first['id'] as String;
  }

  Map<String, dynamic>? get _order => widget.orders
      .where((row) => row['id'] == orderId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  String? get _factoryId => _order?['factory_id'] as String?;
  @override
  void dispose() {
    batchNo.dispose();
    quantity.dispose();
    super.dispose();
  }

  void submit() {
    final qty = num.tryParse(quantity.text.trim());
    if (orderId == null ||
        batchNo.text.trim().isEmpty ||
        qty == null ||
        qty <= 0)
      return;
    Navigator.pop(context, {
      'order_id': orderId,
      'batch_no': batchNo.text.trim(),
      'planned_quantity': qty,
      'shift_id': shiftId,
      'operator_employee_id': operatorId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final shifts = widget.shifts
        .where(
          (row) => row['factory_id'] == null || row['factory_id'] == _factoryId,
        )
        .toList();
    final people = widget.employees
        .where(
          (row) =>
              row['primary_factory_id'] == _factoryId &&
              row['status'] == 'active',
        )
        .toList();
    return AlertDialog(
      title: const Text('Start production batch'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: orderId,
              decoration: const InputDecoration(labelText: 'Production order'),
              items: widget.orders
                  .where(
                    (row) => !const [
                      'completed',
                      'cancelled',
                      'on_hold',
                    ].contains(row['status']),
                  )
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(
                        '${row['order_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Product'}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                orderId = value;
                shiftId = null;
                operatorId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: batchNo,
                    decoration: const InputDecoration(
                      labelText: 'Batch number',
                    ),
                  ),
                ),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Planned quantity',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: shiftId,
              decoration: const InputDecoration(labelText: 'Shift (optional)'),
              items: shifts
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(row['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => shiftId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: operatorId,
              decoration: const InputDecoration(
                labelText: 'Operator (optional)',
              ),
              items: people
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(
                        '${row['full_name']} · ${row['employee_code']}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => operatorId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Start batch')),
      ],
    );
  }
}

class MaterialIssueEditor extends StatefulWidget {
  const MaterialIssueEditor({
    required this.batches,
    required this.components,
    required this.items,
    required this.locations,
    super.key,
  });
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> components;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;

  @override
  State<MaterialIssueEditor> createState() => _MaterialIssueEditorState();
}

class _MaterialIssueEditorState extends State<MaterialIssueEditor> {
  String? batchId;
  String? itemId;
  String? locationId;
  final quantity = TextEditingController(text: '1');
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.isEmpty
        ? null
        : widget.batches.first['id'] as String;
  }

  Map<String, dynamic>? get _batch => widget.batches
      .where((row) => row['id'] == batchId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  String? get _factoryId => _batch?['factory_id'] as String?;
  String? get _recipeId =>
      _nested(_batch ?? const {}, 'production_orders', 'recipe_id');
  List<Map<String, dynamic>> get _allowedComponents =>
      widget.components.where((row) => row['recipe_id'] == _recipeId).toList();
  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final qty = num.tryParse(quantity.text.trim());
    if (batchId == null ||
        itemId == null ||
        locationId == null ||
        qty == null ||
        qty <= 0)
      return;
    Navigator.pop(context, {
      'batch_id': batchId,
      'item_id': itemId,
      'from_location_id': locationId,
      'quantity': qty,
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where(
          (row) => row['factory_id'] == _factoryId && row['is_active'] == true,
        )
        .toList();
    return AlertDialog(
      title: const Text('Issue / consume material'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: batchId,
              decoration: const InputDecoration(labelText: 'Active batch'),
              items: widget.batches
                  .where(
                    (row) =>
                        const ['in_progress', 'paused'].contains(row['status']),
                  )
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(
                        '${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                batchId = value;
                itemId = null;
                locationId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'BOM material'),
              items: _allowedComponents.map((component) {
                final item = widget.items
                    .where((row) => row['id'] == component['item_id'])
                    .cast<Map<String, dynamic>?>()
                    .firstOrNull;
                return DropdownMenuItem(
                  value: component['item_id'] as String,
                  child: Text(
                    item == null
                        ? 'Material'
                        : '${item['name']} · ${item['sku']}',
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => itemId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: locationId,
              decoration: const InputDecoration(labelText: 'Source location'),
              items: locations
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['name']} · ${row['code']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => locationId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Issue material')),
      ],
    );
  }
}

class OutputEditor extends StatefulWidget {
  const OutputEditor({
    required this.batches,
    required this.locations,
    super.key,
  });
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> locations;
  @override
  State<OutputEditor> createState() => _OutputEditorState();
}

class _OutputEditorState extends State<OutputEditor> {
  String? batchId;
  String? locationId;
  final good = TextEditingController(text: '1');
  final scrap = TextEditingController(text: '0');
  final lot = TextEditingController();
  final reason = TextEditingController();
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.isEmpty
        ? null
        : widget.batches.first['id'] as String;
  }

  Map<String, dynamic>? get _batch => widget.batches
      .where((row) => row['id'] == batchId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  String? get _factoryId => _batch?['factory_id'] as String?;
  @override
  void dispose() {
    good.dispose();
    scrap.dispose();
    lot.dispose();
    reason.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final g = num.tryParse(good.text.trim());
    final s = num.tryParse(scrap.text.trim());
    if (batchId == null ||
        g == null ||
        s == null ||
        g < 0 ||
        s < 0 ||
        g + s <= 0 ||
        (g > 0 && locationId == null))
      return;
    Navigator.pop(context, {
      'batch_id': batchId,
      'good_quantity': g,
      'scrap_quantity': s,
      'to_location_id': g > 0 ? locationId : null,
      'lot_batch_no': lot.text.trim().isEmpty ? null : lot.text.trim(),
      'scrap_reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where(
          (row) => row['factory_id'] == _factoryId && row['is_active'] == true,
        )
        .toList();
    return AlertDialog(
      title: const Text('Record production output'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: batchId,
                decoration: const InputDecoration(labelText: 'Active batch'),
                items: widget.batches
                    .where(
                      (row) => const [
                        'in_progress',
                        'paused',
                      ].contains(row['status']),
                    )
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text(
                          '${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  batchId = value;
                  locationId = null;
                }),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: good,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Good quantity',
                      ),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: scrap,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Scrap quantity',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: locationId,
                decoration: const InputDecoration(
                  labelText: 'Finished-goods destination',
                ),
                items: locations
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['code']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => locationId = value),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: lot,
                decoration: const InputDecoration(
                  labelText: 'Lot / batch number',
                ),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Scrap reason (when applicable)',
                ),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: notes,
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
        FilledButton(onPressed: submit, child: const Text('Record output')),
      ],
    );
  }
}

class DowntimeEditor extends StatefulWidget {
  const DowntimeEditor({required this.batches, super.key});
  final List<Map<String, dynamic>> batches;
  @override
  State<DowntimeEditor> createState() => _DowntimeEditorState();
}

class _DowntimeEditorState extends State<DowntimeEditor> {
  String? batchId;
  final code = TextEditingController(text: 'BREAKDOWN');
  final minutes = TextEditingController(text: '15');
  final reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.isEmpty
        ? null
        : widget.batches.first['id'] as String;
  }

  @override
  void dispose() {
    code.dispose();
    minutes.dispose();
    reason.dispose();
    super.dispose();
  }

  void submit() {
    final duration = int.tryParse(minutes.text.trim());
    if (batchId == null ||
        code.text.trim().length < 2 ||
        duration == null ||
        duration <= 0)
      return;
    Navigator.pop(context, {
      'batch_id': batchId,
      'reason_code': code.text.trim().toUpperCase().replaceAll(' ', '_'),
      'duration_minutes': duration,
      'reason_text': reason.text.trim().isEmpty ? null : reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log downtime'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: batchId,
            decoration: const InputDecoration(labelText: 'Active batch'),
            items: widget.batches
                .where(
                  (row) =>
                      const ['in_progress', 'paused'].contains(row['status']),
                )
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(
                      '${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => batchId = value),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Reason code'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration minutes'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'Reason / remarks'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Save downtime')),
    ],
  );
}

String? _nested(Map<String, dynamic> row, String object, String key) =>
    row[object] is Map ? (row[object] as Map)[key] as String? : null;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
