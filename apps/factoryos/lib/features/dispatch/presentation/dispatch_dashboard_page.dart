import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/dispatch_repository.dart';

class DispatchDashboardPage extends StatelessWidget {
  const DispatchDashboardPage({super.key, required this.repository});
  final DispatchRepository repository;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dispatch', style: TextStyle(fontWeight: FontWeight.w800)), Text('Finished Goods • Outbound operations', style: TextStyle(fontSize: 12, color: AppTheme.muted))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/delivery'), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Delivery queue')))],
      ),
      body: FutureBuilder<DispatchOverview>(
        future: repository.loadOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text('Unable to load dispatch.'));
          final data = snapshot.requireData;
          return ListView(padding: const EdgeInsets.all(24), children: [
            Wrap(spacing: 14, runSpacing: 14, children: [
              _Metric(label: 'Ready orders', value: '${data.readyOrders}'),
              _Metric(label: 'Loading', value: '${data.loadingOrders}', accent: AppTheme.brand),
              _Metric(label: 'Dispatched today', value: '${data.dispatchedToday}', accent: AppTheme.success),
              _Metric(label: 'Blocked', value: '${data.blockedOrders}', accent: AppTheme.danger),
            ]),
            const SizedBox(height: 18),
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dispatch queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...data.orders.map((order) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${order.orderNumber} • ${order.customer}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${order.city} • ${order.packages} packages • ${order.weightKg.toStringAsFixed(0)} kg'), trailing: Text(order.status, style: TextStyle(color: order.status == 'QC blocked' ? AppTheme.danger : order.status == 'Ready' ? AppTheme.success : AppTheme.brand, fontWeight: FontWeight.w800)))),
            ]))),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final bays = _Bays(bays: data.bays);
              final checks = _Checks(checks: data.checks);
              if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: bays), const SizedBox(width: 16), Expanded(child: checks)]);
              return Column(children: [bays, const SizedBox(height: 16), checks]);
            }),
          ]);
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
  Widget build(BuildContext context) => SizedBox(width: 245, height: 124, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent))]))));
}

class _Bays extends StatelessWidget {
  const _Bays({required this.bays});
  final List<LoadingBay> bays;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Loading bays', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 16),
    ...bays.map((bay) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(bay.name, style: const TextStyle(fontWeight: FontWeight.w800)), Text(bay.vehicle, style: const TextStyle(color: AppTheme.muted))]), const SizedBox(height: 8), LinearProgressIndicator(value: bay.progress, minHeight: 10, borderRadius: BorderRadius.circular(5))]))),
  ])));
}

class _Checks extends StatelessWidget {
  const _Checks({required this.checks});
  final List<DispatchCheck> checks;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Documents & checks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    ...checks.map((check) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(check.complete ? Icons.check_circle : Icons.schedule, color: check.complete ? AppTheme.success : AppTheme.warning), title: Text(check.label, style: TextStyle(fontWeight: FontWeight.w700, color: check.complete ? AppTheme.text : AppTheme.warning)))),
  ])));
}
