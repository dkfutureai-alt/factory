import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/sales_repository.dart';
import '../domain/sales_models.dart';

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.repository, required this.customerCode});
  final SalesRepository repository;
  final String customerCode;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Customer Detail', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Commercial profile, orders and credit position', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('New sales order')))],
        ),
        body: FutureBuilder<CustomerDetail>(
          future: repository.loadCustomer(customerCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load customer.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(data.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${data.customerCode} • ${data.city}, ${data.state} • ${data.status}', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final cards = <Widget>[
                    _InfoCard(title: 'Customer profile', rows: [
                      ('GSTIN', data.gstinMasked),
                      ('Credit terms', '${data.creditDays} days'),
                      ('Credit limit', _money(data.creditLimit)),
                      ('Account owner', data.accountOwner),
                    ]),
                    _InfoCard(title: 'Contact & delivery', rows: [
                      ('Primary contact', data.primaryContact),
                      ('Phone', data.phoneMasked),
                      ('Email', data.emailMasked),
                      ('Default delivery', data.defaultDelivery),
                    ]),
                    _AccountSummary(data: data),
                  ];
                  if (constraints.maxWidth > 1000) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < cards.length; i++) ...[Expanded(child: cards[i]), if (i != cards.length - 1) const SizedBox(width: 16)]]);
                  return Wrap(spacing: 16, runSpacing: 16, children: cards.map((card) => SizedBox(width: constraints.maxWidth > 620 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth, child: card)).toList());
                }),
                const SizedBox(height: 18),
                _RecentOrders(orders: data.recentOrders),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final commercial = _CommercialNotes(data: data);
                  final attention = _AccountAttention(data: data);
                  if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: commercial), const SizedBox(width: 16), Expanded(child: attention)]);
                  return Column(children: [commercial, const SizedBox(height: 16), attention]);
                }),
              ],
            );
          },
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 118, child: Text(row.$1, style: const TextStyle(fontSize: 12, color: AppTheme.muted))),
                    Expanded(child: Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                )),
          ]),
        ),
      );
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.data});
  final CustomerDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _SummaryRow(label: 'YTD sales', value: _money(data.ytdSales)),
            _SummaryRow(label: 'Open orders', value: '${data.openOrders}'),
            _SummaryRow(label: 'Outstanding', value: _money(data.outstanding), accent: AppTheme.warning),
            _SummaryRow(label: 'On-time payment', value: '${(data.onTimePaymentRate * 100).toStringAsFixed(0)}%', accent: AppTheme.success),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted))), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: accent))]),
      );
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});
  final List<SalesOrderSummary> orders;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent sales orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...orders.map((order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).pushNamed('/sales/order'),
                  title: Text(order.orderNumber, style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
                  subtitle: Text('${_money(order.totalValue)} • Dispatch ${order.dispatchDateLabel} • Delivery ${order.deliveryStatus}'),
                  trailing: Text(order.isPaid ? 'Paid' : '${_money(order.paymentOutstanding)} pending', style: TextStyle(fontWeight: FontWeight.w800, color: order.isPaid ? AppTheme.success : AppTheme.warning)),
                )),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _CommercialNotes extends StatelessWidget {
  const _CommercialNotes({required this.data});
  final CustomerDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Commercial notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('• Standard credit: ${data.creditDays} days from invoice\n• Dispatch allowed within approved credit limit\n• Freight billed separately for non-contract routes', style: const TextStyle(color: AppTheme.muted, height: 1.8)),
          ]),
        ),
      );
}

class _AccountAttention extends StatelessWidget {
  const _AccountAttention({required this.data});
  final CustomerDetail data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account attention', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('${_money(data.outstanding)} currently outstanding', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Current balance remains within configured credit terms.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 14),
            Text('Credit utilized: ${(data.creditUtilization * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}
