import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';
import 'maintenance_asset_page.dart';

class MaintenancePlanPage extends StatelessWidget {
  const MaintenancePlanPage({super.key, required this.repository});
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preventive Maintenance Planner', style: TextStyle(fontWeight: FontWeight.w800))),
    body: FutureBuilder<MaintenancePlan>(
      future: repository.loadPlan(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load maintenance plan.'));
        final plan = snapshot.requireData;
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Text('Upcoming service windows', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Planned servicing and due dates • fictional demo schedule', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _Metric('Scheduled entries', '${plan.entries.length}', AppTheme.brand),
            _Metric('Completed this month', '${plan.completedThisMonth}', AppTheme.success),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Service schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...plan.entries.map((entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined, color: AppTheme.brand),
              title: Text('${entry.assetCode} • ${entry.assetName}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${entry.task} • ${entry.dueAt.day}/${entry.dueAt.month}/${entry.dueAt.year}'),
              trailing: Text(entry.status, style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintenanceAssetPage(repository: repository, code: entry.assetCode))),
            )),
            const SizedBox(height: 12),
            const Text('Each preventive schedule occurrence may create only one work order. No automatic jobs are created in preview mode.', style: TextStyle(color: AppTheme.muted)),
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
  Widget build(BuildContext context) => SizedBox(width: 245, height: 122, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.w800)),
    ],
  ))));
}
