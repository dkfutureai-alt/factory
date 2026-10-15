import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';
import 'maintenance_asset_page.dart';
import 'maintenance_work_order_page.dart';

class MaintenanceDashboardPage extends StatelessWidget {
  const MaintenanceDashboardPage({super.key, required this.repository});
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Maintenance Management', style: TextStyle(fontWeight: FontWeight.w800)),
      Text('Machines, preventive servicing and breakdowns', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
    ])),
    body: FutureBuilder<MaintenanceOverview>(
      future: repository.loadOverview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load maintenance data.'));
        final data = snapshot.requireData;
        return ListView(padding: const EdgeInsets.all(24), children: [
          Wrap(spacing: 14, runSpacing: 14, children: [
            _Metric('Assets online', '${data.operationalAssets} / ${data.totalAssets}', AppTheme.success),
            _Metric('PM due this week', '${data.pmDue}', AppTheme.warning),
            _Metric('Open breakdowns', '${data.breakdowns}', AppTheme.danger),
            _Metric('Work orders active', '${data.orders.length}', AppTheme.brand),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/maintenance/plan'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Preventive planner'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/maintenance/breakdowns'),
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Breakdowns & spares'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/maintenance/reports'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Maintenance reports'),
            ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final queue = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Work order queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...data.orders.map((order) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.build_outlined, color: AppTheme.brand),
                title: Text('${order.number} • ${order.assetName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${order.type} • ${order.assignee} • ${order.priority}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintenanceWorkOrderPage(repository: repository, number: order.number))),
              )),
            ])));
            final assets = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Assets requiring attention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...data.assets.map((asset) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${asset.code} • ${asset.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${asset.location} • ${asset.status} • Next ${asset.nextService}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintenanceAssetPage(repository: repository, code: asset.code))),
              )),
            ])));
            if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: queue), const SizedBox(width: 16), Expanded(flex: 2, child: assets)]);
            return Column(children: [queue, const SizedBox(height: 16), assets]);
          }),
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
  Widget build(BuildContext context) => SizedBox(width: 245, height: 126, child: Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: color)),
    ]),
  )));
}
