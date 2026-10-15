import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/fleet_repository.dart';
import '../domain/fleet_models.dart';

class FleetDashboardPage extends StatelessWidget {
  const FleetDashboardPage({super.key, required this.repository});
  final FleetRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fleet & Transport', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Vehicles, drivers, trips and fuel operations', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () => Navigator.of(context).pushNamed('/fleet/trips'), icon: const Icon(Icons.add_road), label: const Text('Create trip')))],
        ),
        body: FutureBuilder<FleetOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load fleet data.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Active vehicles', value: '${data.activeVehicles} / ${data.totalVehicles}', detail: '${(data.availabilityRate * 100).toStringAsFixed(0)}% available'),
                _Metric(label: 'Trips today', value: '${data.tripsToday}', detail: 'planned and running', accent: AppTheme.brand),
                _Metric(label: 'Drivers on duty', value: '${data.driversOnDuty}', detail: 'active duty records'),
                _Metric(label: 'Fuel spend MTD', value: '₹${(data.fuelSpendMonth / 100000).toStringAsFixed(2)}L', detail: 'month to date', accent: AppTheme.warning),
              ]),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Vehicle availability', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...data.vehicles.map((vehicle) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).pushNamed('/fleet/vehicle'),
                      leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                      title: Text(vehicle.registration, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand)),
                      subtitle: Text('${vehicle.type} • ${vehicle.driverName} • ${vehicle.odometerKm} km'),
                      trailing: Text(vehicle.status, style: TextStyle(fontWeight: FontWeight.w800, color: _statusColor(vehicle.status))),
                    )),
              ]))),
              const SizedBox(height: 18),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(width: 520, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Attention required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...data.alerts.map((alert) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.warning_amber_rounded, color: _alertColor(alert.severity)), title: Text(alert.title, style: TextStyle(fontWeight: FontWeight.w800, color: _alertColor(alert.severity))), subtitle: Text(alert.detail))),
                ])))),
                SizedBox(width: 520, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Fleet actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined, color: AppTheme.brand), title: const Text('Driver management'), onTap: () => Navigator.of(context).pushNamed('/fleet/driver')),
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.route_outlined, color: AppTheme.brand), title: const Text('Trip management'), onTap: () => Navigator.of(context).pushNamed('/fleet/trips')),
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.local_gas_station_outlined, color: AppTheme.brand), title: const Text('Fuel management'), onTap: () => Navigator.of(context).pushNamed('/fleet/fuel')),
                ])))),
              ]),
            ]);
          },
        ),
      );

  static Color _statusColor(String status) => switch (status) {
        'Available' || 'On trip' => AppTheme.success,
        'Service due' => AppTheme.warning,
        _ => AppTheme.muted,
      };

  static Color _alertColor(FleetAlertSeverity severity) => switch (severity) {
        FleetAlertSeverity.info => AppTheme.brand,
        FleetAlertSeverity.warning => AppTheme.warning,
        FleetAlertSeverity.danger => AppTheme.danger,
      };
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
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        ]))),
      );
}
