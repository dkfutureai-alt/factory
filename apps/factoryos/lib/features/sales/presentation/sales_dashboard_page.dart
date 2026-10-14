import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/sales_repository.dart';
import '../domain/sales_models.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key, required this.repository});
  final SalesRepository repository;

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(value >= 1000000 ? 1 : 2)}L';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sales & Customers', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Main Manufacturing Plant • Customer orders and revenue pipeline', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Create sales order')))],
        ),
        body: FutureBuilder<SalesOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load sales data.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(spacing: 14, runSpacing: 14, children: [
                  _Metric(label: 'Open sales orders', value: '${data.openOrders}', detail: '${_money(data.committedValue)} committed value'),
                  _Metric(label: 'Due for dispatch', value: '${data.dueForDispatch}', detail: 'next 72 hours', accent: AppTheme.brand),
                  _Metric(label: 'Payment pending', value: _money(data.paymentPending), detail: 'customer outstanding', accent: AppTheme.warning),
                  _Metric(label: 'Delivered this month', value: '${data.deliveredThisMonth}', detail: 'completed deliveries', accent: AppTheme.success),
                ]),
                const SizedBox(height: 18),
                _OrderQueue(orders: data.orders),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final customers = _TopCustomers(items: data.topCustomers);
                  final alerts = _AttentionPanel(items: data.alerts);
                  if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: customers), const SizedBox(width: 16), Expanded(child: alerts)]);
                  return Column(children: [customers, const SizedBox(height: 16), alerts]);
                }),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 126,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 4),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _OrderQueue extends StatelessWidget {
  const _OrderQueue({required this.orders});
  final List<SalesOrderSummary> orders;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sales order queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...orders.map((order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).pushNamed('/sales/order'),
                  title: Row(children: [
                    Text(order.orderNumber, style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(child: InkWell(onTap: () => Navigator.of(context).pushNamed('/sales/customer'), child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700)))),
                  ]),
                  subtitle: Text('Dispatch ${order.dispatchDateLabel} • ${order.isPaid ? 'Paid' : _pendingLabel(order.paymentOutstanding)}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(order.orderStatus, style: TextStyle(fontWeight: FontWeight.w800, color: _statusColor(order.orderStatus))),
                    const SizedBox(height: 3),
                    Text('Delivery: ${order.deliveryStatus}', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                  ]),
                )),
          ]),
        ),
      );

  static String _pendingLabel(double value) => '₹${(value / 100000).toStringAsFixed(2)}L pending';
  static Color _statusColor(String status) => switch (status) {
        'Delivered' || 'Closed' => AppTheme.success,
        'Production' => AppTheme.warning,
        _ => AppTheme.brand,
      };
}

class _TopCustomers extends StatelessWidget {
  const _TopCustomers({required this.items});
  final List<CustomerRevenueSummary> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Top customers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).pushNamed('/sales/customer'),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(item.customerCode),
                  trailing: Text('₹${(item.ytdRevenue / 100000).toStringAsFixed(1)}L YTD', style: const TextStyle(fontWeight: FontWeight.w800)),
                )),
          ]),
        ),
      );
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.items});
  final List<SalesAlert> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Attention required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 10, color: _severityColor(item.severity)),
                  title: Text(item.title, style: TextStyle(fontWeight: FontWeight.w800, color: _severityColor(item.severity))),
                  subtitle: Text(item.detail),
                )),
          ]),
        ),
      );

  static Color _severityColor(SalesAlertSeverity severity) => switch (severity) {
        SalesAlertSeverity.danger => AppTheme.danger,
        SalesAlertSeverity.warning => AppTheme.warning,
        SalesAlertSeverity.info => AppTheme.brand,
      };
}
