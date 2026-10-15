import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';

class MaintenanceReportsPage extends StatelessWidget {
  const MaintenanceReportsPage({super.key, required this.repository});
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Maintenance Reports', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Reliability, downtime and cost performance', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
        body: FutureBuilder<MaintenanceReportSnapshot>(
          future: repository.loadReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load maintenance reports.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric('Asset availability', '${(data.assetAvailabilityRate * 100).toStringAsFixed(1)}%', AppTheme.success),
                _Metric('PM compliance', '${(data.pmComplianceRate * 100).toStringAsFixed(0)}%', AppTheme.brand),
                _Metric('Breakdown hours MTD', '${data.breakdownHoursMonth.toStringAsFixed(1)}h', AppTheme.danger),
                _Metric('Maintenance cost MTD', '₹${(data.maintenanceCostMonth / 1000).toStringAsFixed(1)}k', AppTheme.warning),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final reliability = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Reliability trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ...data.reliability.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      SizedBox(width: 120, child: Text(point.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Expanded(child: LinearProgressIndicator(value: point.availabilityRate.clamp(0, 1).toDouble(), minHeight: 9, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 14),
                      SizedBox(width: 72, child: Text('${(point.availabilityRate * 100).toStringAsFixed(1)}%')),
                      SizedBox(width: 75, child: Text('MTTR ${point.mttrHours.toStringAsFixed(1)}h', style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
                    ]),
                  )),
                  Text('Current MTTR ${data.currentMttrHours.toStringAsFixed(1)}h', style: const TextStyle(color: AppTheme.muted)),
                ])));
                final costs = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Cost split MTD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  _Cost('Spare parts', data.spareCostMonth),
                  _Cost('Labour', data.laborCostMonth),
                  _Cost('External service', data.externalServiceCostMonth),
                  const Divider(height: 28),
                  _Cost('Total', data.maintenanceCostMonth, bold: true),
                ])));
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: reliability), const SizedBox(width: 16), Expanded(child: costs)]);
                return Column(children: [reliability, const SizedBox(height: 16), costs]);
              }),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Top downtime assets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...data.topDowntimeAssets.map((asset) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.precision_manufacturing_outlined, color: AppTheme.brand),
                      title: Text('${asset.assetCode} • ${asset.assetName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: Text('${asset.hours.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.danger)),
                    )),
              ]))),
            ]);
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 245, height: 126, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 8), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: color))]))));
}

class _Cost extends StatelessWidget {
  const _Cost(this.label, this.amount, {this.bold = false});
  final String label;
  final double amount;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))), Text('₹${(amount / 1000).toStringAsFixed(1)}k', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700))]));
}
