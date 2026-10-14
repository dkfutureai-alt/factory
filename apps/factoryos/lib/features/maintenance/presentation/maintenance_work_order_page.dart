import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';

class MaintenanceWorkOrderPage extends StatelessWidget {
  const MaintenanceWorkOrderPage({super.key, required this.repository, required this.number});
  final MaintenanceRepository repository;
  final String number;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Maintenance Work Order', style: TextStyle(fontWeight: FontWeight.w800))),
    body: FutureBuilder<MaintenanceWorkOrderDetail>(
      future: repository.loadWorkOrder(number),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load work order.'));
        final job = snapshot.requireData;
        return ListView(padding: const EdgeInsets.all(24), children: [
          Text(job.number, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${job.assetCode} • ${job.assetName} • ${job.type}', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(width: 600, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Work order checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ...job.checklist.map((task) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_box_outline_blank, color: AppTheme.brand), title: Text(task))),
              const SizedBox(height: 8),
              Text('Assigned to ${job.assignee}', style: const TextStyle(color: AppTheme.muted)),
            ])))),
            SizedBox(width: 390, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Job controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _Info('Status', job.status),
              _Info('Priority', job.priority),
              _Info('Downtime', '${job.downtime.inMinutes} min recorded'),
              _Info('Safety cleared', job.safetyCleared ? 'Yes' : 'No'),
              const SizedBox(height: 8),
              Text(job.canClose ? 'Closure conditions satisfied; live approval is not connected.' : 'Closure blocked until resolution, safety clearance and spare issues are verified.',
                style: TextStyle(color: job.canClose ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.w700)),
            ])))),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Spare parts / Inventory handoff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ...job.spares.map((part) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${part.sku} • ${part.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Requested ${part.requestedQuantity.toStringAsFixed(0)} • Posted issue ${part.postedIssueQuantity.toStringAsFixed(0)}'),
              trailing: Text(part.fullyIssued ? 'Issued' : '${part.pendingQuantity.toStringAsFixed(0)} pending',
                style: TextStyle(fontWeight: FontWeight.w700, color: part.fullyIssued ? AppTheme.success : AppTheme.warning)),
            )),
            const SizedBox(height: 8),
            const Text('Only posted maintenance_issue stock ledger entries count as consumed. Preview does not modify stock.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/inventory'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Open Inventory')),
          ]))),
        ]);
      },
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [
    SizedBox(width: 132, child: Text(label, style: const TextStyle(color: AppTheme.muted))),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
  ]));
}
