import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/fleet_repository.dart';
import '../domain/fleet_models.dart';

class TripManagementPage extends StatelessWidget {
  const TripManagementPage({super.key, required this.repository});
  final FleetRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Trip Management', style: TextStyle(fontWeight: FontWeight.w800)), Text('Plan, assign, dispatch and complete trips', style: TextStyle(fontSize: 12, color: AppTheme.muted))]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Create trip')))],
        ),
        body: FutureBuilder<List<TripSummary>>(
          future: repository.loadTrips(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load trips.'));
            final trips = snapshot.requireData;
            final inProgress = trips.where((trip) => trip.status == 'In progress').length;
            final delayed = trips.where((trip) => trip.status == 'Vehicle hold').length;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Trips loaded', value: '${trips.length}', detail: 'preview queue'),
                _Metric(label: 'In progress', value: '$inProgress', detail: 'currently running', accent: AppTheme.brand),
                const _Metric(label: 'Completed today', value: '7', detail: 'delivery or transfer', accent: AppTheme.success),
                _Metric(label: 'Delayed / blocked', value: '$delayed', detail: 'requires action', accent: AppTheme.danger),
              ]),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Today’s trip queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...trips.map((trip) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.route_outlined, color: AppTheme.brand),
                      title: Text(trip.tripNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand)),
                      subtitle: Text('${trip.route} • ${trip.vehicleRegistration} • ${trip.driverName} • ${trip.plannedTime}'),
                      trailing: Text(trip.status, style: TextStyle(fontWeight: FontWeight.w800, color: _statusColor(trip.status))),
                    )),
              ]))),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final dispatch = const _InfoCard(title: 'Dispatch readiness', icon: Icons.inventory_2_outlined, detail: '9 trips linked to dispatches • 1 awaiting loading clearance');
                final confirmations = const _InfoCard(title: 'Driver confirmations', icon: Icons.fact_check_outlined, detail: '12 accepted • 2 pending acknowledgement');
                if (constraints.maxWidth > 900) return Row(children: [Expanded(child: dispatch), const SizedBox(width: 16), Expanded(child: confirmations)]);
                return Column(children: [dispatch, const SizedBox(height: 16), confirmations]);
              }),
            ]);
          },
        ),
      );

  static Color _statusColor(String status) => switch (status) {
        'In progress' => AppTheme.brand,
        'Ready' || 'Completed' => AppTheme.success,
        'Vehicle hold' => AppTheme.danger,
        _ => AppTheme.muted,
      };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String detail;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(width: 245, height: 142, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)), const SizedBox(height: 4), Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.muted))]))));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.detail});
  final String title;
  final IconData icon;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon, color: AppTheme.brand), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(detail, style: const TextStyle(color: AppTheme.muted))]))])));
}
