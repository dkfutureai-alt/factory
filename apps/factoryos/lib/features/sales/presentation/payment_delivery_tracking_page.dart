import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/sales_repository.dart';
import '../domain/sales_models.dart';

class PaymentDeliveryTrackingPage extends StatelessWidget {
  const PaymentDeliveryTrackingPage({super.key, required this.repository, required this.orderNumber});
  final SalesRepository repository;
  final String orderNumber;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payment & Delivery Tracking', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Collections and logistics handoff status', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
        body: FutureBuilder<PaymentDeliveryTracking>(
          future: repository.loadTracking(orderNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load tracking data.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(data.orderNumber, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(data.customerName, style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final payment = _PaymentCard(data: data);
                  final delivery = _DeliveryCard(data: data);
                  if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: payment), const SizedBox(width: 16), Expanded(child: delivery)]);
                  return Column(children: [payment, const SizedBox(height: 16), delivery]);
                }),
                const SizedBox(height: 18),
                _PaymentHistory(data: data),
                const SizedBox(height: 18),
                _DeliveryTimeline(data: data),
              ],
            );
          },
        ),
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.data});
  final PaymentDeliveryTracking data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _Row(label: 'Invoice total', value: _money(data.invoiceTotal)),
            _Row(label: 'Received', value: _money(data.received), accent: AppTheme.success),
            _Row(label: 'Outstanding', value: _money(data.outstanding), accent: data.outstanding > 0 ? AppTheme.warning : AppTheme.success),
            _Row(label: 'Due date', value: data.dueDateLabel),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: data.collectionRate, minHeight: 10, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 8),
            Text('${(data.collectionRate * 100).toStringAsFixed(1)}% collected • within configured credit terms', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.data});
  final PaymentDeliveryTracking data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Delivery status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _Row(label: 'Dispatch target', value: data.dispatchTargetLabel),
            _Row(label: 'Dispatch note', value: data.dispatchReference),
            _Row(label: 'Vehicle', value: data.vehicleLabel),
            _Row(label: 'Driver', value: data.driverName),
            _Row(label: 'Current state', value: data.deliveryState, accent: AppTheme.brand),
            const SizedBox(height: 8),
            const Text('Delivery state is read from Dispatch / Trip workflows; Sales does not maintain a duplicate editable status.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 128, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted))), Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: accent)))]),
      );
}

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({required this.data});
  final PaymentDeliveryTracking data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment history', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...data.payments.map((payment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(payment.reference, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${payment.dateLabel} • ${payment.method}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_money(payment.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(payment.status, style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                )),
            const Divider(height: 28),
            Text('Remaining ${_money(data.outstanding)} is not overdue.', style: const TextStyle(color: AppTheme.muted)),
          ]),
        ),
      );

  static String _money(double value) => '₹${(value / 100000).toStringAsFixed(2)}L';
}

class _DeliveryTimeline extends StatelessWidget {
  const _DeliveryTimeline({required this.data});
  final PaymentDeliveryTracking data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Delivery timeline', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: data.deliverySteps.map((step) => _Step(step: step)).toList()),
          ]),
        ),
      );
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
