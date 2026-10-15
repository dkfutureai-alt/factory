import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/purchase_order_workflow_repository.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_models.dart';
import 'purchase_order_detail_page.dart';
import 'purchase_order_editor_page.dart';

class PurchaseDashboardPage extends StatelessWidget {
  const PurchaseDashboardPage({
    super.key,
    required this.repository,
    this.workflowRepository = const PreviewPurchaseOrderWorkflowRepository(),
  });

  final PurchaseRepository repository;
  final PurchaseOrderWorkflowRepository workflowRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purchase', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Main Manufacturing Plant • Procurement control', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              key: const Key('create-purchase-order'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PurchaseOrderEditorPage(repository: workflowRepository),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create purchase order'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<PurchaseOverview>(
        future: repository.loadOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text('Unable to load purchase data.'));
          final data = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Open purchase orders', value: '${data.openOrders}'),
                  _Metric(label: 'Pending approval', value: '${data.pendingApproval}', accent: AppTheme.warning),
                  _Metric(label: 'Due this week', value: '${data.dueThisWeek}', accent: AppTheme.brand),
                  _Metric(label: 'Outstanding value', value: '₹${(data.outstandingValue / 100000).toStringAsFixed(1)}L'),
                ],
              ),
              const SizedBox(height: 18),
              _PurchaseOrderQueue(
                orders: data.orders,
                repository: repository,
                workflowRepository: workflowRepository,
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final suppliers = _SupplierPanel(items: data.suppliers);
                  final receipts = _ReceiptPanel(items: data.receipts);
                  if (constraints.maxWidth > 900) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: suppliers), const SizedBox(width: 16), Expanded(child: receipts)]);
                  }
                  return Column(children: [suppliers, const SizedBox(height: 16), receipts]);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

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
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
        ),
      );
}

class _PurchaseOrderQueue extends StatelessWidget {
  const _PurchaseOrderQueue({required this.orders, required this.repository, required this.workflowRepository});
  final List<PurchaseOrderSummary> orders;
  final PurchaseRepository repository;
  final PurchaseOrderWorkflowRepository workflowRepository;

  Color _statusColor(PurchaseOrderSummary order) {
    if (order.status == 'Overdue' || order.isOverdue) return AppTheme.danger;
    if (order.status == 'Pending approval') return AppTheme.warning;
    if (order.status == 'Approved') return AppTheme.success;
    return AppTheme.brand;
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Purchase order queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...orders.map(
                (order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PurchaseOrderDetailPage(
                        repository: repository,
                        orderNumber: order.orderNumber,
                        workflowRepository: workflowRepository,
                      ),
                    ),
                  ),
                  title: Text('${order.orderNumber} • ${order.supplier}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Expected ${order.expectedDate.day}/${order.expectedDate.month}/${order.expectedDate.year} • ₹${(order.totalValue / 100000).toStringAsFixed(2)}L'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(order.status, style: TextStyle(color: _statusColor(order), fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SupplierPanel extends StatelessWidget {
  const _SupplierPanel({required this.items});
  final List<SupplierPerformance> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Supplier performance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text('${(item.onTimeRate * 100).toStringAsFixed(0)}% on time', style: TextStyle(fontWeight: FontWeight.w800, color: item.onTimeRate >= .9 ? AppTheme.success : AppTheme.warning)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ReceiptPanel extends StatelessWidget {
  const _ReceiptPanel({required this.items});
  final List<GoodsReceiptSummary> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent goods receipts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.grnNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success)),
                  subtitle: Text('${item.orderNumber} • ${item.lineCount} line${item.lineCount == 1 ? '' : 's'}'),
                  trailing: Text(item.receivedLabel, style: const TextStyle(color: AppTheme.muted)),
                ),
              ),
            ],
          ),
        ),
      );
}