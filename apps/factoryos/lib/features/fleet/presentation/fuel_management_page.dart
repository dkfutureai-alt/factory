import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/fleet_repository.dart';
import '../domain/fleet_models.dart';

class FuelManagementPage extends StatelessWidget {
  const FuelManagementPage({super.key, required this.repository});
  final FleetRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fuel Management', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Fuel entries, mileage, cost variance and review', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Fuel entry')))],
        ),
        body: FutureBuilder<FuelOverview>(
          future: repository.loadFuelOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load fuel data.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Fuel MTD', value: '${data.totalLitresMonth.toStringAsFixed(0)} L', detail: 'month to date'),
                _Metric(label: 'Spend MTD', value: '₹${(data.spendMonth / 100000).toStringAsFixed(2)}L', detail: 'approved fuel spend'),
                _Metric(label: 'Fleet mileage', value: '${data.fleetMileageKmPerLitre.toStringAsFixed(1)} km/L', detail: 'derived from entries', accent: AppTheme.success),
                _Metric(label: 'Variance alerts', value: '${data.varianceAlerts}', detail: 'below tolerance', accent: data.varianceAlerts == 0 ? AppTheme.success : AppTheme.danger),
              ]),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent fuel entries', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...data.entries.map((entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_gas_station_outlined, color: AppTheme.brand),
                      title: Text('${entry.entryNumber} • ${entry.vehicleRegistration}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${entry.driverName} • ${entry.odometerKm} km • ${entry.litres.toStringAsFixed(1)} L • ₹${entry.amount.toStringAsFixed(0)}'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${entry.mileageKmPerLitre.toStringAsFixed(1)} km/L', style: TextStyle(fontWeight: FontWeight.w800, color: entry.reviewStatus == 'Review' ? AppTheme.danger : AppTheme.success)),
                        const SizedBox(height: 3),
                        Text(entry.reviewStatus, style: TextStyle(fontSize: 11, color: entry.reviewStatus == 'Review' ? AppTheme.danger : AppTheme.success)),
                      ]),
                    )),
              ]))),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final alerts = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Efficiency watch', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...data.entries.where((entry) => entry.reviewStatus == 'Review').map((entry) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger), title: Text(entry.vehicleRegistration, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.danger)), subtitle: Text('${entry.mileageKmPerLitre.toStringAsFixed(1)} km/L vs ${data.targetMileageKmPerLitre.toStringAsFixed(1)} target'))),
                ])));
                final controls = const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fuel controls', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 12),
                  Text('• Odometer must move forward for the same vehicle.', style: TextStyle(color: AppTheme.muted)),
                  SizedBox(height: 10),
                  Text('• Driver and vehicle assignment must match trip/duty context.', style: TextStyle(color: AppTheme.muted)),
                  SizedBox(height: 10),
                  Text('• Approved entries are auditable; corrections use controlled reversal/update flow.', style: TextStyle(color: AppTheme.muted)),
                ])));
                if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: alerts), const SizedBox(width: 16), Expanded(child: controls)]);
                return Column(children: [alerts, const SizedBox(height: 16), controls]);
              }),
            ]);
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
        height: 146,
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          const SizedBox(height: 8),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]))),
      );
}
