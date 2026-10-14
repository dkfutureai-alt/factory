import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_models.dart';

class PurchaseOrderDetailPage extends StatelessWidget {
  const PurchaseOrderDetailPage({super.key, required this.repository, required this.orderNumber});
  final PurchaseRepository repository;
  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(orderNumber, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder<PurchaseOrderDetail>(
        future: repository.loadOrder(orderNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text('Unable to load purchase order.'));
          final detail = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(detail.supplier, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Expected ${detail.expectedDateLabel}', style: const TextStyle(color: AppTheme.muted)),
                    ]),
                  ),
                  FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Record receipt')),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Order value', value: _money(detail.orderValue)),
                  _Metric(label: 'Received value', value: _money(detail.receivedValue), accent: AppTheme.success),
                  _Metric(label: 'Pending value', value: _money(detail.pendingValue), accent: AppTheme.warning),
                  _Metric(label: 'Status', value: detail.status, accent: AppTheme.brand, compact: true),
                ],
              ),
              const SizedBox(height: 18),
              _OrderLines(detail: detail),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final supplier = _CommercialTerms(detail: detail);
                  final checks = _Checks(detail: detail);
                  if (constraints.maxWidth > 900) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: supplier), const SizedBox(width: 16), Expanded(child: checks)]);
                  }
                  return Column(children: [supplier, const SizedBox(height: 16), checks]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text, this.compact = false});
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 120,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: compact ? 20 : 26, fontWeight: FontWeight.w800, color: accent), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.detail});
  final PurchaseOrderDetail detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order lines', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...detail.lines.map(
                (line) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${line.sku} • ${line.itemName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Ordered ${line.orderedQuantity.toStringAsFixed(0)} ${line.unit} • Received ${line.receivedQuantity.toStringAsFixed(0)} ${line.unit}'),
                  trailing: Text(
                    line.fullyReceived ? 'Complete' : '${line.pendingQuantity.toStringAsFixed(0)} ${line.unit} pending',
                    style: TextStyle(fontWeight: FontWeight.w800, color: line.fullyReceived ? AppTheme.success : AppTheme.warning),
                  ),
                ),
              ),
              const Divider(),
              const Text('Receiving rule: accepted quantity posts to the existing inventory ledger only after GRN checks complete.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text('Latest GRN: ${detail.latestGrn}', style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _CommercialTerms extends StatelessWidget {
  const _CommercialTerms({required this.detail});
  final PurchaseOrderDetail detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Supplier & commercial terms', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _Field(label: 'Supplier', value: detail.supplier),
            _Field(label: 'Payment terms', value: detail.paymentTerms),
            _Field(label: 'Delivery location', value: detail.deliveryLocation),
          ]),
        ),
      );
}

class _Checks extends StatelessWidget {
  const _Checks({required this.detail});
  final PurchaseOrderDetail detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Approval & receiving checks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...detail.checks.map(
              (check) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(check.complete ? Icons.check_circle : Icons.schedule, color: check.complete ? AppTheme.success : AppTheme.warning),
                title: Text(check.label, style: TextStyle(fontWeight: FontWeight.w700, color: check.complete ? AppTheme.text : AppTheme.warning)),
              ),
            ),
          ]),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
