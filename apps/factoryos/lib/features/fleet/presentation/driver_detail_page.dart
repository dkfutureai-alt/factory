import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/fleet_repository.dart';
import '../domain/fleet_models.dart';

class DriverDetailPage extends StatelessWidget {
  const DriverDetailPage({super.key, required this.repository, required this.employeeCode});
  final FleetRepository repository;
  final String employeeCode;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Driver Detail', style: TextStyle(fontWeight: FontWeight.w800)), Text('Compliance, assignments and performance', style: TextStyle(fontSize: 12, color: AppTheme.muted))])),
        body: FutureBuilder<DriverDetail>(
          future: repository.loadDriver(employeeCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load driver.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
                const CircleAvatar(radius: 30, child: Text('RJ', style: TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${data.employeeCode} • ${data.designation}', style: const TextStyle(color: AppTheme.muted)), const SizedBox(height: 8), Text('Assigned vehicle: ${data.assignedVehicle}', style: const TextStyle(fontWeight: FontWeight.w700))])),
                _Mini(label: 'Duty status', value: data.dutyStatus, accent: AppTheme.success),
                const SizedBox(width: 20),
                _Mini(label: 'Distance MTD', value: '${data.distanceMonthKm} km'),
              ]))),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final compliance = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('License & compliance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _Row(label: 'License class', value: data.licenseClass),
                  _Row(label: 'License validity', value: data.licenseValidity, accent: AppTheme.success),
                  const _Row(label: 'Medical check', value: 'Valid', accent: AppTheme.success),
                  const _Row(label: 'Safety training', value: 'Completed', accent: AppTheme.success),
                ])));
                final performance = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Performance snapshot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _Row(label: 'On-time deliveries', value: '${(data.onTimeDeliveryRate * 100).toStringAsFixed(1)}%'),
                  _Row(label: 'Fuel variance', value: '${(data.fuelVarianceRate * 100).toStringAsFixed(1)}%', accent: data.fuelVarianceRate <= 0 ? AppTheme.success : AppTheme.warning),
                  _Row(label: 'Safety incidents YTD', value: '${data.safetyIncidentsYear}'),
                  _Row(label: 'Distance MTD', value: '${data.distanceMonthKm} km'),
                ])));
                if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: compliance), const SizedBox(width: 16), Expanded(child: performance)]);
                return Column(children: [compliance, const SizedBox(height: 16), performance]);
              }),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent assignments', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('TRIP-2026-00814', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand)), subtitle: const Text('Plant → CityCare Hospital'), trailing: const Text('In progress', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)), onTap: () => Navigator.of(context).pushNamed('/fleet/trips')),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('TRIP-2026-00809', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Plant → Metro Engineering'), trailing: const Text('Completed', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800))),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted))), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: accent))]));
}
