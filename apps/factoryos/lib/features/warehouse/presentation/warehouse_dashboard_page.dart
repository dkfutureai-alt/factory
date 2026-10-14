import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/warehouse_repository.dart';

class WarehouseDashboardPage extends StatelessWidget {
  const WarehouseDashboardPage({super.key, required this.repository});
  final WarehouseRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warehouse', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Central Warehouse • Live operations', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        ),
      ),
      body: FutureBuilder<WarehouseOverview>(
        future: repository.loadOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text('Unable to load warehouse.'));
          final data = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Receipts today', value: '${data.receiptsToday}'),
                  _Metric(label: 'Issues today', value: '${data.issuesToday}'),
                  _Metric(label: 'Transfers', value: '${data.transfersToday}', accent: AppTheme.brand),
                  _Metric(label: 'Pending putaway', value: '${data.pendingPutaway}', accent: AppTheme.warning),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tasks = _Tasks(tasks: data.tasks);
                  final utilization = _Utilization(items: data.utilization);
                  if (constraints.maxWidth > 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: tasks),
                        const SizedBox(width: 16),
                        Expanded(child: utilization),
                      ],
                    );
                  }
                  return Column(children: [tasks, const SizedBox(height: 16), utilization]);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label, value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 124,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
        ),
      );
}

class _Tasks extends StatelessWidget {
  const _Tasks({required this.tasks});
  final List<WarehouseTask> tasks;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Operational tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...tasks.map(
                (task) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: task.reference == 'TRF-2026-00218' ? () => Navigator.of(context).pushNamed('/warehouse/transfer') : null,
                  title: Text('${task.type} • ${task.reference}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${task.detail}\n${task.assignee}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.status,
                        style: TextStyle(
                          color: task.status == 'Pending' ? AppTheme.warning : task.status == 'Ready' ? AppTheme.success : AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (task.reference == 'TRF-2026-00218') const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Utilization extends StatelessWidget {
  const _Utilization({required this.items});
  final List<WarehouseUtilization> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Location utilization', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${(item.percent * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.muted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: item.percent, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
