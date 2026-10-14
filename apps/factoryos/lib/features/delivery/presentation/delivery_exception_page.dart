import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_models.dart';

class DeliveryExceptionPage extends StatelessWidget {
  const DeliveryExceptionPage({super.key, required this.repository, required this.deliveryNumber});
  final DeliveryRepository repository;
  final String deliveryNumber;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivery Exception / Return', style: TextStyle(fontWeight: FontWeight.w800)), Text('Rejected quantity, evidence and return handoff', style: TextStyle(fontSize: 12, color: AppTheme.muted))]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.assignment_return_outlined), label: const Text('Create return movement')))],
        ),
        body: FutureBuilder<DeliveryExceptionDetail>(
          future: repository.loadException(deliveryNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load delivery exception.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Text('${data.deliveryNumber} • ${data.customer}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Exception type', value: data.exceptionType, accent: AppTheme.danger),
                _Metric(label: 'Rejected qty', value: data.rejectedQuantity.toStringAsFixed(0)),
                _Metric(label: 'Return trip', value: data.returnTripNumber, accent: AppTheme.warning),
                _Metric(label: 'Resolution', value: data.resolutionStatus, accent: AppTheme.warning),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final rejected = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Rejected items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...data.lines.map((line) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${line.itemCode} • ${line.itemName}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Delivered ${line.plannedQuantity.toStringAsFixed(0)} • Accepted ${line.acceptedQuantity.toStringAsFixed(0)} • Rejected ${line.rejectedQuantity.toStringAsFixed(0)} • ${line.rejectionReason ?? 'Reason pending'}'))),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Customer note', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(data.customerNote, style: const TextStyle(color: AppTheme.muted)),
                  const SizedBox(height: 12),
                  Text('${data.evidenceCount} evidence files captured', style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w700)),
                ])));
                final flow = const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Resolution workflow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 14),
                  _Step(label: 'Delivery exception recorded', done: true),
                  _Step(label: 'Supervisor review', active: true),
                  _Step(label: 'Return trip / pickup'),
                  _Step(label: 'Warehouse return receipt'),
                  _Step(label: 'Sales resolution / replacement'),
                ])));
                if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: rejected), const SizedBox(width: 16), Expanded(child: flow)]);
                return Column(children: [rejected, const SizedBox(height: 16), flow]);
              }),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Inventory handoff rule', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Rejected goods do not increase warehouse stock here. An approved physical warehouse receipt must post a customer_return inventory ledger transaction.', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 10),
                Text(data.requiresReturn ? 'Return handling required.' : 'No physical return is required.', style: TextStyle(fontWeight: FontWeight.w800, color: data.requiresReturn ? AppTheme.warning : AppTheme.success)),
              ]))),
            ]);
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(width: 245, height: 128, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)), const SizedBox(height: 8), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: accent))]))));
}

class _Step extends StatelessWidget {
  const _Step({required this.label, this.done = false, this.active = false});
  final String label;
  final bool done;
  final bool active;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Icon(done ? Icons.check_circle : active ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: done ? AppTheme.success : active ? AppTheme.brand : AppTheme.muted), const SizedBox(width: 10), Expanded(child: Text(label, style: TextStyle(fontWeight: done || active ? FontWeight.w800 : FontWeight.w500, color: active ? AppTheme.brand : AppTheme.text)))]));
}
