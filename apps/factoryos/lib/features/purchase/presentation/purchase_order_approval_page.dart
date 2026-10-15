import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/purchase_order_workflow_repository.dart';
import '../domain/purchase_order_workflow_models.dart';

class PurchaseOrderApprovalPage extends StatefulWidget {
  const PurchaseOrderApprovalPage({super.key, required this.repository, required this.orderNumber});

  final PurchaseOrderWorkflowRepository repository;
  final String orderNumber;

  @override
  State<PurchaseOrderApprovalPage> createState() => _PurchaseOrderApprovalPageState();
}

class _PurchaseOrderApprovalPageState extends State<PurchaseOrderApprovalPage> {
  final _commentController = TextEditingController();
  PurchaseOrderEditorOptions? _options;
  Object? _loadError;
  bool _loading = true;
  bool _acting = false;
  late String _approveKey;
  late String _rejectKey;

  @override
  void initState() {
    super.initState();
    _approveKey = _newKey('po-approve');
    _rejectKey = _newKey('po-reject');
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _newKey(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _load() async {
    try {
      final data = await widget.repository.loadEditor(orderNumber: widget.orderNumber);
      if (!mounted) return;
      setState(() {
        _options = data;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _decide(PurchaseOrderDecision decision) async {
    final draft = _options?.draft;
    if (draft == null || _acting) return;
    if (!widget.repository.supportsMutations) {
      _message('Preview mode: approval actions are disabled until FactoryOS Supabase is connected.');
      return;
    }
    if (!draft.isPendingApproval) {
      _message('This purchase order is no longer pending approval.');
      return;
    }
    final request = PurchaseOrderDecisionRequest(
      purchaseOrderId: draft.purchaseOrderId,
      decision: decision,
      comment: _commentController.text,
      idempotencyKey: decision == PurchaseOrderDecision.approve ? _approveKey : _rejectKey,
    );
    final validation = request.validate();
    if (validation != null) {
      _message(validation);
      return;
    }
    setState(() => _acting = true);
    try {
      final result = await widget.repository.decide(request);
      if (!mounted) return;
      setState(() {
        _acting = false;
        if (decision == PurchaseOrderDecision.approve) {
          _approveKey = _newKey('po-approve');
        } else {
          _rejectKey = _newKey('po-reject');
        }
      });
      _message(decision == PurchaseOrderDecision.approve ? '${result.orderNumber} approved and ready for receiving.' : '${result.orderNumber} returned to draft.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      _message('Purchase order decision failed: $error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Purchase Order Approval', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(widget.orderNumber, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: FilledButton(onPressed: _load, child: const Text('Retry approval load')))
                : _buildContent(_options!),
      );

  Widget _buildContent(PurchaseOrderEditorOptions data) {
    final draft = data.draft;
    if (draft == null) return const Center(child: Text('Purchase order not found.'));
    final supplier = data.supplierById(draft.supplierId);
    final factory = data.factories.where((item) => item.id == draft.factoryId).firstOrNull;
    final pending = draft.isPendingApproval;

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1050;
      final details = ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(draft.orderNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${supplier?.name ?? 'Supplier'} • ${factory?.code ?? 'Factory'} • Revision ${draft.revision}', style: const TextStyle(color: AppTheme.muted)),
                  ])),
                  _StatusChip(status: draft.status),
                ]),
                const SizedBox(height: 20),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  _Metric(label: 'Line value', value: _money(draft.lineValue)),
                  _Metric(label: 'Estimated tax', value: _money(draft.taxValue), accent: AppTheme.brand),
                  _Metric(label: 'Estimated total', value: _money(draft.totalValue)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Order lines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...draft.lines.map((line) {
                  final item = data.itemById(line.itemId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item?.sku ?? 'SKU'} • ${item?.name ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${line.orderedQuantity.toStringAsFixed(2)} ${item?.unit ?? ''} × ₹${line.unitPrice.toStringAsFixed(2)} • Tax ${line.taxRate.toStringAsFixed(1)}%'),
                    trailing: Text(_money(line.totalValue), style: const TextStyle(fontWeight: FontWeight.w800)),
                  );
                }),
                const Divider(),
                _Field(label: 'Expected delivery', value: _date(draft.expectedDeliveryDate)),
                _Field(label: 'Payment terms', value: draft.paymentTerms.isEmpty ? 'Not specified' : draft.paymentTerms),
                _Field(label: 'Requester note', value: draft.notes.isEmpty ? 'None' : draft.notes),
              ]),
            ),
          ),
        ],
      );
      final decision = ListView(
        padding: EdgeInsets.fromLTRB(wide ? 0 : 24, 24, 24, 24),
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Approval checks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const _Check(text: 'Supplier and factory are server-validated'),
                const _Check(text: 'Submitted PO lines are frozen'),
                const _Check(text: 'Quantities, pricing and tax are validated'),
                const _Check(text: 'approval.act is checked at exact factory scope'),
                const _Check(text: 'Decision creates an audit event'),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  enabled: pending,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Review comment', hintText: 'Required when rejecting'),
                ),
                const SizedBox(height: 16),
                Text(widget.repository.supportsMutations ? 'Live mode • audited server decision' : 'Preview mode • no database mutation', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: pending && !_acting ? () => _decide(PurchaseOrderDecision.reject) : null, child: const Text('Reject'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: pending && !_acting ? () => _decide(PurchaseOrderDecision.approve) : null, child: Text(_acting ? 'Processing…' : 'Approve PO'))),
                ]),
                if (!pending) ...[
                  const SizedBox(height: 14),
                  Text('Current state: ${draft.status.replaceAll('_', ' ')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (draft.rejectionReason != null) Text('Reason: ${draft.rejectionReason}', style: const TextStyle(color: AppTheme.danger)),
                ],
              ]),
            ),
          ),
        ],
      );
      if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: details), SizedBox(width: 430, child: decision)]);
      return ListView(children: [details, decision]);
    });
  }

  static String _money(double value) => '₹${value.toStringAsFixed(0)}';
  static String _date(DateTime? value) => value == null ? 'Not set' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)), const SizedBox(height: 6), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent))]),
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending_approval';
    final approved = status == 'approved' || status == 'part_received' || status == 'received';
    final color = approved ? AppTheme.success : pending ? AppTheme.warning : AppTheme.brand;
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w800))),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [const Icon(Icons.check_circle, color: AppTheme.success, size: 20), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))]),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 150, child: Text(label, style: const TextStyle(color: AppTheme.muted))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );
}

extension _FirstOrNullApproval<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}