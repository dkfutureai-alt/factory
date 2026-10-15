import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/sales_repository.dart';
import '../domain/sales_models.dart';

class SalesOrderDetailPage extends StatelessWidget {
  const SalesOrderDetailPage({super.key, required this.repository, required this.orderNumber});
  final SalesRepository repository;
  final String orderNumber;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sales Order Detail', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Commercial, reservation and lifecycle status', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () => Navigator.of(context).pushNamed('/sales/tracking'), icon: const Icon(Icons.route_outlined), label: const Text('Open tracking')))],
        ),
        body: FutureBuilder<SalesOrderDetail>(
          future: repository.loadOrder(orderNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load sales order.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(data.orderNumber, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${data.customerName} • Created ${data.createdDateLabel} • ${data.status}', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  _Metric(label: 'Order value', value: _money(data.totalValue), detail: 'before freight'),
                  _Metric(label: 'Payment received', value: _money(data.amountReceived), detail: '${_money(data.amountOutstanding)} pending', accent: AppTheme.success),
                  _Metric(label: 'Dispatch target', value: data.dispatchTargetLabel, detail: 'Finished Goods Warehouse', accent: AppTheme.brand, compact: true),
                  _Metric(label: 'Current state', value: data.status, detail: data.fullyReserved ? 'inventory reserved' : 'reservation incomplete', accent: data.fullyReserved ? AppTheme.brand : AppTheme.warning),
                ]),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final lines = _OrderLines(data: data);
                  final terms = _CommercialPanel(data: data);
                  if (constraints.maxWidth > 930) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: lines), const SizedBox(width: 16), Expanded(child: terms)]);
                  return Column(children: [lines, const SizedBox(height: 16), terms]);
                }),
                const SizedBox(height: 18),
                _LifecyclePanel(data: data),
              ],
            );
          },
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail, this.accent = AppTheme.text, this.compact = false});
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 19 : 25, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 4),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.data});
  final SalesOrderDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Order lines', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...data.lines.map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${line.sku} • ${line.itemName}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${line.reservedQuantity.toStringAsFixed(0)} / ${line.quantity.toStringAsFixed(0)} ${line.unit} reserved', style: TextStyle(fontSize: 12, color: line.reservationShortage == 0 ? AppTheme.success : AppTheme.warning))])),
                    Expanded(child: Text('${line.quantity.toStringAsFixed(0)} ${line.unit}')),
                    Expanded(child: Text('₹${line.unitPrice.toStringAsFixed(0)}')),
                    Expanded(child: Text(_money(line.lineValue), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                )),
            const Divider(height: 26),
            Row(children: [const Expanded(child: Text('Order total', style: TextStyle(fontWeight: FontWeight.w800))), Text(_money(data.totalValue), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 12),
            Text(data.fullyReserved ? 'All order quantities are reserved in finished goods.' : 'Reservation shortage requires warehouse action.', style: TextStyle(color: data.fullyReserved ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _CommercialPanel extends StatelessWidget {
  const _CommercialPanel({required this.data});
  final SalesOrderDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Commercial & delivery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _Row(label: 'Customer PO', value: data.customerPo),
            _Row(label: 'Payment terms', value: data.paymentTerms),
            _Row(label: 'Delivery method', value: data.deliveryMethod),
            _Row(label: 'Ship-to', value: data.shipTo),
            _Row(label: 'Outstanding', value: _money(data.amountOutstanding), accent: data.amountOutstanding > 0 ? AppTheme.warning : AppTheme.success),
            _Row(label: 'Dispatch', value: data.dispatchTargetLabel, accent: AppTheme.brand),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted))), Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: accent)))]),
      );
}

class _LifecyclePanel extends StatelessWidget {
  const _LifecyclePanel({required this.data});
  final SalesOrderDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Order lifecycle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: data.lifecycle.map((step) => _Step(step: step)).toList()),
            const SizedBox(height: 18),
            Text('${_money(data.amountOutstanding)} remains due within customer credit terms.', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Dispatch release should depend on credit policy and finished-goods reservation.', style: TextStyle(color: AppTheme.muted)),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _Step extends StatelessWidget {
  const _Step({required this.step});
  final SalesLifecycleStep step;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      SalesLifecycleState.complete => AppTheme.success,
      SalesLifecycleState.current => AppTheme.brand,
      SalesLifecycleState.pending => AppTheme.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(step.state == SalesLifecycleState.complete ? Icons.check_circle : Icons.circle_outlined, size: 16, color: color), const SizedBox(width: 6), Text(step.label, style: TextStyle(color: color, fontWeight: step.state == SalesLifecycleState.current ? FontWeight.w800 : FontWeight.w600))]),
    );
  }
}
