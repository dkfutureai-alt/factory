import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_models.dart';

class DeliveryDetailPage extends StatelessWidget {
  const DeliveryDetailPage({super.key, required this.repository, required this.deliveryNumber, this.driverMode = false});
  final DeliveryRepository repository;
  final String deliveryNumber;
  final bool driverMode;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivery Detail', style: TextStyle(fontWeight: FontWeight.w800)), Text('Quantity reconciliation and proof of delivery', style: TextStyle(fontSize: 12, color: AppTheme.muted))]),
          actions: [if (!driverMode) Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.location_on_outlined), label: const Text('Mark arrived')))],
        ),
        body: FutureBuilder<DeliveryDetail>(
          future: repository.loadDelivery(deliveryNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load delivery.'));
            final data = snapshot.requireData;
            return ListView(padding: EdgeInsets.all(driverMode ? 16 : 24), children: [
              Text(data.deliveryNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${data.customer} • ${data.salesOrderNumber} • ${data.tripNumber}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Status', value: data.status, accent: AppTheme.brand),
                _Metric(label: 'Planned qty', value: data.plannedQuantity.toStringAsFixed(0)),
                _Metric(label: 'Accepted', value: data.acceptedQuantity.toStringAsFixed(0), accent: AppTheme.success),
                _Metric(label: 'POD', value: data.podStatus, accent: data.hasPodEvidence ? AppTheme.success : AppTheme.warning),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final details = _DetailsCard(data: data);
                final pod = _PodCard(data: data, driverMode: driverMode);
                if (constraints.maxWidth > 850) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: details), const SizedBox(width: 16), Expanded(child: pod)]);
                return Column(children: [details, const SizedBox(height: 16), pod]);
              }),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Delivery items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...data.lines.map((line) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${line.itemCode} • ${line.itemName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Planned ${line.plannedQuantity.toStringAsFixed(0)} • Accepted ${line.acceptedQuantity.toStringAsFixed(0)} • Rejected ${line.rejectedQuantity.toStringAsFixed(0)}${line.rejectionReason == null ? '' : ' • ${line.rejectionReason}'}'),
                      trailing: Text(line.reconciled ? 'Reconciled' : '${line.pendingQuantity.toStringAsFixed(0)} pending', style: TextStyle(fontWeight: FontWeight.w800, color: line.reconciled ? AppTheme.success : AppTheme.warning)),
                    )),
              ]))),
              const SizedBox(height: 18),
              if (driverMode) ...[
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.verified_outlined), label: Text(data.canComplete ? 'Confirm delivery' : 'Complete delivery checklist'))),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/delivery/exception'), icon: const Icon(Icons.report_problem_outlined, color: AppTheme.danger), label: const Text('Report exception'))),
              ] else
                Text(data.canComplete ? 'Ready for delivery completion.' : 'Completion is blocked until quantities are reconciled and POD evidence is captured.', style: TextStyle(fontWeight: FontWeight.w700, color: data.canComplete ? AppTheme.success : AppTheme.warning)),
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
  Widget build(BuildContext context) => SizedBox(width: 245, height: 126, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)), const SizedBox(height: 8), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent))]))));
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.data});
  final DeliveryDetail data;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Delivery details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _Info(label: 'Ship to', value: data.shipTo),
        _Info(label: 'Driver', value: '${data.driverName} • ${data.driverCode}'),
        _Info(label: 'Vehicle', value: data.vehicleRegistration),
        _Info(label: 'ETA', value: data.etaLabel),
      ])));
}

class _PodCard extends StatelessWidget {
  const _PodCard({required this.data, required this.driverMode});
  final DeliveryDetail data;
  final bool driverMode;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Proof of delivery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _Info(label: 'Receiver', value: data.receiverName.isEmpty ? 'Pending' : data.receiverName),
        _Info(label: 'Delivered at', value: data.deliveredAtLabel),
        _Info(label: 'Accepted qty', value: data.acceptedQuantity.toStringAsFixed(0)),
        _Info(label: 'Evidence', value: data.hasPodEvidence ? 'Captured' : 'Not captured'),
        if (driverMode) OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Capture POD')),
      ])));
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}
