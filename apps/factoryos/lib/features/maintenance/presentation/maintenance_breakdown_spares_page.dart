import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';

class MaintenanceBreakdownSparesPage extends StatelessWidget {
  const MaintenanceBreakdownSparesPage({super.key, required this.repository});
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Breakdowns & Spare Parts', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Corrective work and Inventory-ledger handoff', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
        body: FutureBuilder<MaintenanceBreakdownOverview>(
          future: repository.loadBreakdowns(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load breakdown data.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric('Open breakdowns', '${data.openBreakdowns}', AppTheme.danger),
                _Metric('Waiting for parts', '${data.waitingForParts}', AppTheme.warning),
                _Metric('Parts issued today', '${data.partsIssuedToday}', AppTheme.brand),
                _Metric('Critical stock alerts', '${data.criticalStockAlerts}', AppTheme.danger),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final queue = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Breakdown queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...data.orders.map((order) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.warning_amber_rounded, color: order.priority == 'Critical' ? AppTheme.danger : AppTheme.warning),
                            title: Text('${order.number} • ${order.assetCode} ${order.assetName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${order.priority} • ${order.status} • ${order.assignee}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).pushNamed('/maintenance/work-order'),
                          )),
                      const Divider(height: 32),
                      const Text('Spare requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...data.spares.map((part) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(part.stockAlert ? Icons.inventory_2_outlined : Icons.settings_outlined, color: part.stockAlert ? AppTheme.danger : AppTheme.brand),
                            title: Text('${part.sku} • ${part.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${part.workOrderNumber} • Requested ${part.requestedQuantity.toStringAsFixed(0)} • Posted ${part.postedIssueQuantity.toStringAsFixed(0)}'),
                            trailing: Text(part.fullyIssued ? 'Issued' : '${part.pendingQuantity.toStringAsFixed(0)} pending', style: TextStyle(fontWeight: FontWeight.w800, color: part.fullyIssued ? AppTheme.success : AppTheme.warning)),
                          )),
                      const SizedBox(height: 10),
                      const Text('Only posted maintenance_issue stock-ledger entries count as consumed. Preview actions never modify stock.', style: TextStyle(color: AppTheme.muted)),
                    ]),
                  ),
                );
                final handoff = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Inventory handoff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      _Status('Ledger issues posted', '${data.partsIssuedToday}', data.partsIssuedToday > 0 ? AppTheme.success : AppTheme.warning),
                      _Status('Waiting requirements', '${data.spares.where((e) => !e.fullyIssued).length}', AppTheme.warning),
                      _Status('Closure gate', data.allSparesReady ? 'Ready' : 'Blocked', data.allSparesReady ? AppTheme.success : AppTheme.danger),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/inventory'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Open Inventory'))),
                    ]),
                  ),
                );
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: queue), const SizedBox(width: 16), Expanded(child: handoff)]);
                return Column(children: [queue, const SizedBox(height: 16), handoff]);
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
  Widget build(BuildContext context) => SizedBox(width: 245, height: 126, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: color))]))));
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted))), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color))]));
}
