import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/purchase_order_workflow_repository.dart';
import '../domain/purchase_order_workflow_models.dart';

class PurchaseOrderEditorPage extends StatefulWidget {
  const PurchaseOrderEditorPage({super.key, required this.repository, this.orderNumber});

  final PurchaseOrderWorkflowRepository repository;
  final String? orderNumber;

  @override
  State<PurchaseOrderEditorPage> createState() => _PurchaseOrderEditorPageState();
}

class _PurchaseOrderEditorPageState extends State<PurchaseOrderEditorPage> {
  final _paymentTermsController = TextEditingController();
  final _notesController = TextEditingController();
  PurchaseOrderEditorOptions? _options;
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;
  String? _factoryId;
  String? _supplierId;
  DateTime? _expectedDate;
  List<PurchaseOrderDraftLine> _lines = const [];
  String? _purchaseOrderId;
  String? _orderNumber;
  int? _revision;
  String _status = 'draft';
  String? _rejectionReason;
  late String _saveKey;
  late String _submitKey;

  @override
  void initState() {
    super.initState();
    _saveKey = _newKey('po-save');
    _submitKey = _newKey('po-submit');
    _load();
  }

  @override
  void dispose() {
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _newKey(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _load() async {
    try {
      final data = await widget.repository.loadEditor(orderNumber: widget.orderNumber);
      if (!mounted) return;
      final draft = data.draft;
      setState(() {
        _options = data;
        _loadError = null;
        _loading = false;
        _factoryId = draft?.factoryId ?? (data.factories.isEmpty ? null : data.factories.first.id);
        _supplierId = draft?.supplierId ?? (data.suppliers.isEmpty ? null : data.suppliers.first.id);
        _expectedDate = draft?.expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 7));
        _lines = List<PurchaseOrderDraftLine>.from(draft?.lines ?? const []);
        _purchaseOrderId = draft?.purchaseOrderId;
        _orderNumber = draft?.orderNumber;
        _revision = draft?.revision;
        _status = draft?.status ?? 'draft';
        _rejectionReason = draft?.rejectionReason;
        _paymentTermsController.text = draft?.paymentTerms ?? _defaultTerms(data, _supplierId);
        _notesController.text = draft?.notes ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  String _defaultTerms(PurchaseOrderEditorOptions data, String? supplierId) {
    final supplier = data.supplierById(supplierId);
    return supplier == null ? '' : '${supplier.paymentTermsDays} days from accepted GRN';
  }

  PurchaseOrderDraftRequest? _request() {
    final factoryId = _factoryId;
    final supplierId = _supplierId;
    if (factoryId == null || supplierId == null) return null;
    return PurchaseOrderDraftRequest(
      purchaseOrderId: _purchaseOrderId,
      expectedRevision: _revision,
      factoryId: factoryId,
      supplierId: supplierId,
      expectedDeliveryDate: _expectedDate,
      paymentTerms: _paymentTermsController.text,
      notes: _notesController.text,
      lines: _lines,
      idempotencyKey: _saveKey,
    );
  }

  Future<PurchaseOrderWorkflowResult?> _save({bool quiet = false}) async {
    final data = _options;
    if (data == null || _saving) return null;
    if (!widget.repository.supportsMutations) {
      if (!quiet) _message('Preview mode: connect the dedicated FactoryOS Supabase backend to save purchase orders.');
      return null;
    }
    if (_status != 'draft') {
      _message('Only draft purchase orders can be edited.');
      return null;
    }
    final request = _request();
    if (request == null) {
      _message('Select a factory and supplier.');
      return null;
    }
    final validation = request.validate(data);
    if (validation != null) {
      _message(validation);
      return null;
    }
    setState(() => _saving = true);
    try {
      final result = await widget.repository.saveDraft(request);
      if (!mounted) return null;
      setState(() {
        _saving = false;
        _purchaseOrderId = result.purchaseOrderId;
        _orderNumber = result.orderNumber;
        _revision = result.revision;
        _status = result.status;
        _rejectionReason = result.rejectionReason;
        _saveKey = _newKey('po-save');
      });
      if (!quiet) _message('${result.orderNumber} draft saved.');
      return result;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _saving = false);
      _message('Purchase order save failed: $error');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!widget.repository.supportsMutations) {
      _message('Preview mode: approval submission is disabled until FactoryOS Supabase is connected.');
      return;
    }
    if (_lines.isEmpty) {
      _message('Add at least one purchase item before submission.');
      return;
    }
    final saved = await _save(quiet: true);
    if (saved == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await widget.repository.submit(
        purchaseOrderId: saved.purchaseOrderId,
        expectedRevision: saved.revision,
        idempotencyKey: _submitKey,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _revision = result.revision;
        _status = result.status;
        _submitKey = _newKey('po-submit');
      });
      _message('${result.orderNumber} submitted for approval.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Purchase order submission failed: $error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _expectedDate = selected);
  }

  void _addLine(PurchaseOrderEditorOptions data) {
    final used = _lines.map((line) => line.itemId).toSet();
    final available = data.items.where((item) => !used.contains(item.id));
    if (available.isEmpty) {
      _message('All visible purchase items are already on this order.');
      return;
    }
    final item = available.first;
    setState(() {
      _lines = [
        ..._lines,
        PurchaseOrderDraftLine(itemId: item.id, orderedQuantity: 1, unitPrice: item.defaultUnitPrice, taxRate: 18),
      ];
    });
  }

  void _replaceLine(int index, PurchaseOrderDraftLine line) {
    final next = List<PurchaseOrderDraftLine>.from(_lines);
    next[index] = line;
    setState(() => _lines = next);
  }

  void _removeLine(int index) {
    final next = List<PurchaseOrderDraftLine>.from(_lines)..removeAt(index);
    setState(() => _lines = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_orderNumber == null ? 'Create Purchase Order' : 'Edit $_orderNumber', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Text('Draft → Submit → Approval → GRN', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: FilledButton(onPressed: _load, child: const Text('Retry purchase order load')))
                : _buildContent(_options!),
      );

  Widget _buildContent(PurchaseOrderEditorOptions data) {
    final request = _request();
    final editable = _status == 'draft';
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final editor = _EditorPanel(
          data: data,
          editable: editable,
          factoryId: _factoryId,
          supplierId: _supplierId,
          expectedDate: _expectedDate,
          paymentTermsController: _paymentTermsController,
          notesController: _notesController,
          lines: _lines,
          onFactoryChanged: (value) => setState(() => _factoryId = value),
          onSupplierChanged: (value) {
            setState(() {
              _supplierId = value;
              if (_paymentTermsController.text.trim().isEmpty) {
                _paymentTermsController.text = _defaultTerms(data, value);
              }
            });
          },
          onPickDate: _pickDate,
          onAddLine: () => _addLine(data),
          onReplaceLine: _replaceLine,
          onRemoveLine: _removeLine,
        );
        final summary = _SummaryPanel(
          request: request,
          status: _status,
          revision: _revision,
          rejectionReason: _rejectionReason,
          supportsMutations: widget.repository.supportsMutations,
          saving: _saving,
          canEdit: editable,
          onSave: () => _save(),
          onSubmit: _submit,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 7, child: editor), SizedBox(width: 420, child: summary)],
          );
        }
        return ListView(children: [editor, summary]);
      },
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.data,
    required this.editable,
    required this.factoryId,
    required this.supplierId,
    required this.expectedDate,
    required this.paymentTermsController,
    required this.notesController,
    required this.lines,
    required this.onFactoryChanged,
    required this.onSupplierChanged,
    required this.onPickDate,
    required this.onAddLine,
    required this.onReplaceLine,
    required this.onRemoveLine,
  });

  final PurchaseOrderEditorOptions data;
  final bool editable;
  final String? factoryId;
  final String? supplierId;
  final DateTime? expectedDate;
  final TextEditingController paymentTermsController;
  final TextEditingController notesController;
  final List<PurchaseOrderDraftLine> lines;
  final ValueChanged<String?> onFactoryChanged;
  final ValueChanged<String?> onSupplierChanged;
  final VoidCallback onPickDate;
  final VoidCallback onAddLine;
  final void Function(int, PurchaseOrderDraftLine) onReplaceLine;
  final ValueChanged<int> onRemoveLine;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Order details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  SizedBox(
                    width: 270,
                    child: DropdownButtonFormField<String>(
                      initialValue: factoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Factory'),
                      items: data.factories
                          .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text('${item.code} • ${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: editable ? onFactoryChanged : null,
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                      items: data.suppliers
                          .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: editable ? onSupplierChanged : null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: editable ? onPickDate : null,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(expectedDate == null ? 'Expected delivery' : _date(expectedDate!)),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                TextField(controller: paymentTermsController, enabled: editable, decoration: const InputDecoration(labelText: 'Payment terms')),
                const SizedBox(height: 14),
                TextField(controller: notesController, enabled: editable, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Purchase order lines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  OutlinedButton.icon(onPressed: editable ? onAddLine : null, icon: const Icon(Icons.add), label: const Text('Add item')),
                ]),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No items yet. Drafts may be saved empty, but submission requires at least one line.', style: TextStyle(color: AppTheme.muted))),
                  ),
                ...List.generate(
                  lines.length,
                  (index) => _LineEditor(
                    key: ValueKey('po-line-$index-${lines[index].itemId}'),
                    line: lines[index],
                    items: data.items,
                    enabled: editable,
                    onChanged: (line) => onReplaceLine(index, line),
                    onRemove: () => onRemoveLine(index),
                  ),
                ),
              ]),
            ),
          ),
        ],
      );

  static String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({super.key, required this.line, required this.items, required this.enabled, required this.onChanged, required this.onRemove});
  final PurchaseOrderDraftLine line;
  final List<PurchaseOrderItemOption> items;
  final bool enabled;
  final ValueChanged<PurchaseOrderDraftLine> onChanged;
  final VoidCallback onRemove;

  PurchaseOrderItemOption? _selectedItem() {
    for (final item in items) {
      if (item.id == line.itemId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 310,
              child: DropdownButtonFormField<String>(
                initialValue: line.itemId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item'),
                items: items
                    .map((value) => DropdownMenuItem(
                          value: value.id,
                          child: Text('${value.sku} • ${value.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: enabled
                    ? (value) {
                        if (value == null) return;
                        final nextItem = items.firstWhere((candidate) => candidate.id == value);
                        onChanged(PurchaseOrderDraftLine(itemId: nextItem.id, orderedQuantity: line.orderedQuantity, unitPrice: nextItem.defaultUnitPrice, taxRate: line.taxRate, note: line.note));
                      }
                    : null,
              ),
            ),
            SizedBox(width: 110, child: TextFormField(initialValue: _number(line.orderedQuantity), enabled: enabled, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: item == null || item.unit.isEmpty ? 'Qty' : 'Qty (${item.unit})'), onChanged: (value) => onChanged(PurchaseOrderDraftLine(itemId: line.itemId, orderedQuantity: double.tryParse(value) ?? 0, unitPrice: line.unitPrice, taxRate: line.taxRate, note: line.note)))),
            SizedBox(width: 130, child: TextFormField(initialValue: _number(line.unitPrice), enabled: enabled, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit price'), onChanged: (value) => onChanged(PurchaseOrderDraftLine(itemId: line.itemId, orderedQuantity: line.orderedQuantity, unitPrice: double.tryParse(value) ?? 0, taxRate: line.taxRate, note: line.note)))),
            SizedBox(width: 100, child: TextFormField(initialValue: _number(line.taxRate), enabled: enabled, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tax %'), onChanged: (value) => onChanged(PurchaseOrderDraftLine(itemId: line.itemId, orderedQuantity: line.orderedQuantity, unitPrice: line.unitPrice, taxRate: double.tryParse(value) ?? 0, note: line.note)))),
            SizedBox(width: 120, child: Text('₹${line.totalValue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: enabled ? onRemove : null, tooltip: 'Remove line', icon: const Icon(Icons.delete_outline)),
          ]),
        ),
      ),
    );
  }

  static String _number(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.request, required this.status, required this.revision, required this.rejectionReason, required this.supportsMutations, required this.saving, required this.canEdit, required this.onSave, required this.onSubmit});
  final PurchaseOrderDraftRequest? request;
  final String status;
  final int? revision;
  final String? rejectionReason;
  final bool supportsMutations;
  final bool saving;
  final bool canEdit;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final req = request;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Draft summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              _SummaryMetric(label: 'Line value', value: _money(req?.lineValue ?? 0)),
              _SummaryMetric(label: 'Estimated tax', value: _money(req?.taxValue ?? 0), accent: AppTheme.brand),
              _SummaryMetric(label: 'Estimated total', value: _money(req?.totalValue ?? 0)),
              const Divider(height: 30),
              Text('Status: ${_label(status)}${revision == null ? '' : ' • Revision $revision'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (rejectionReason != null && rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Returned for changes: $rejectionReason', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              Text(supportsMutations ? 'Server commands enforce scope, revision and audit rules.' : 'Preview mode • no database mutation', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: canEdit && !saving ? onSave : null, child: Text(saving ? 'Saving…' : 'Save draft'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: canEdit && !saving ? onSubmit : null, child: const Text('Submit approval'))),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  static String _money(double value) => '₹${value.toStringAsFixed(0)}';
  static String _label(String status) => status.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: accent)),
        ]),
      );
}
