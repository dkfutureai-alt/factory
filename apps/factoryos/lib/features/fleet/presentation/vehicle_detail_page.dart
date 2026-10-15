import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/fleet_repository.dart';
import '../domain/fleet_models.dart';

class VehicleDetailPage extends StatelessWidget {
  const VehicleDetailPage({super.key, required this.repository, required this.registration});
  final FleetRepository repository;
  final String registration;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Vehicle Detail', style: TextStyle(fontWeight: FontWeight.w800)), Text('Compliance, assignment, cost and activity', style: TextStyle(fontSize: 12, color: AppTheme.muted))])),
        body: FutureBuilder<VehicleDetail>(
          future: repository.loadVehicle(registration),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load vehicle.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.local_shipping_outlined)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data.registration, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${data.makeModel} • ${data.capacity} • ${data.fuelType}', style: const TextStyle(color: AppTheme.muted)), const SizedBox(height: 8), Text('Assigned driver: ${data.driverName}', style: const TextStyle(fontWeight: FontWeight.w700))])),
                _Mini(label: 'Odometer', value: '${data.odometerKm} km'),
                const SizedBox(width: 18),
                _Mini(label: 'Next service', value: '${data.nextServiceKm} km', accent: AppTheme.warning),
              ]))),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final docs = _Documents(data: data.documents);
                final costs = _Costs(data: data);
                if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: docs), const SizedBox(width: 16), Expanded(child: costs)]);
                return Column(children: [docs, const SizedBox(height: 16), costs]);
              }),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.route_outlined), title: const Text('TRIP-2026-00814', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Plant → CityCare Hospital'), trailing: const Text('In progress', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)), onTap: () => Navigator.of(context).pushNamed('/fleet/trips')),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.local_gas_station_outlined), title: const Text('FUEL-01472', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('38.2 L • ₹3,780'), trailing: const Text('Reviewed', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800)), onTap: () => Navigator.of(context).pushNamed('/fleet/fuel')),
              ]))),
            ]);
          },
        ),
      );
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 6), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent))]));
}

class _Documents extends StatelessWidget {
  const _Documents({required this.data});
  final List<VehicleDocument> data;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Documents & compliance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    ...data.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item.label), trailing: Text(item.value, style: TextStyle(fontWeight: FontWeight.w800, color: item.isWarning ? AppTheme.warning : AppTheme.success)))),
  ])));
}

class _Costs extends StatelessWidget {
  const _Costs({required this.data});
  final VehicleDetail data;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Cost & utilization', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    _Row(label: 'Fuel MTD', value: '₹${data.fuelSpendMonth.toStringAsFixed(0)}'),
    _Row(label: 'Maintenance YTD', value: '₹${data.maintenanceSpendYear.toStringAsFixed(0)}'),
    _Row(label: 'Average mileage', value: '${data.averageMileageKmPerLitre.toStringAsFixed(1)} km/L'),
    _Row(label: 'Trips this month', value: '${data.tripsThisMonth}'),
  ])));
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted))), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]));
}
