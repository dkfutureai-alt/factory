import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/production_repository.dart';
import '../domain/production_models.dart';

class ProductionDashboardPage extends StatelessWidget {
  const ProductionDashboardPage({super.key, required this.repository});

  final ProductionRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Production', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Main Manufacturing Plant • Morning Shift', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Production order')),
          ),
        ],
      ),
      body: FutureBuilder<ProductionOverview>(
        future: repository.loadOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Unable to load production.'));
          }
          return _ProductionBody(data: snapshot.requireData);
        },
      ),
    );
  }
}

class _ProductionBody extends StatelessWidget {
  const _ProductionBody({required this.data});
  final ProductionOverview data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Today • Morning Shift', style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1080 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 3.4 : 2.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ProductionKpi(label: 'Planned quantity', value: '${data.plannedQuantity}', subtitle: 'units today'),
              _ProductionKpi(label: 'Completed', value: '${data.completedQuantity}', subtitle: '${(data.achievement * 100).toStringAsFixed(1)}% achievement', accent: AppTheme.success),
              _ProductionKpi(label: 'In production', value: '${data.activeOrderCount}', subtitle: 'active orders', accent: AppTheme.brand),
              _ProductionKpi(label: 'Rejected / hold', value: '${data.rejectedOrHoldQuantity}', subtitle: 'requires QC attention', accent: AppTheme.danger),
            ],
          );
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final progress = _ProgressPanel(achievement: data.achievement);
          final alerts = _AlertsPanel(alerts: data.alerts);
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: progress), const SizedBox(width: 16), Expanded(child: alerts)])
              : Column(children: [progress, const SizedBox(height: 16), alerts]);
        }),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Active production orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(children: data.orders.map((order) => _OrderCard(order: order)).toList());
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Order')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Line')),
                      DataColumn(label: Text('Progress')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: data.orders.map((order) => DataRow(cells: [
                      DataCell(Text(order.number, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(SizedBox(width: 260, child: Text(order.product, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(order.line)),
                      DataCell(Text('${order.completed} / ${order.planned}')),
                      DataCell(_ProductionStatus(label: order.status)),
                    ])).toList(),
                  ),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ProductionKpi extends StatelessWidget {
  const _ProductionKpi({required this.label, required this.value, required this.subtitle, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
      );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.achievement});
  final double achievement;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Production progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Planned vs actual output', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            const SizedBox(height: 28),
            LinearProgressIndicator(value: achievement.clamp(0, 1), minHeight: 12, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(achievement * 100).toStringAsFixed(1)}% completed', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Text('Target: 4,800 units', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 28),
            const _HourlyProgress(),
          ]),
        ),
      );
}

class _HourlyProgress extends StatelessWidget {
  const _HourlyProgress();

  @override
  Widget build(BuildContext context) {
    const values = [0.18, 0.31, 0.43, 0.55, 0.63, 0.74, 0.82, 0.9];
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: values[i],
                        child: Container(decoration: BoxDecoration(color: AppTheme.brand.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(5))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${9 + i}:00', style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.alerts});
  final List<ProductionAlert> alerts;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Attention required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: _alertBackground(alert.severity), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(alert.title, style: TextStyle(fontWeight: FontWeight.w800, color: _alertForeground(alert.severity))),
                      const SizedBox(height: 4),
                      Text(alert.detail, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ]),
                  ),
                )),
          ]),
        ),
      );

  static Color _alertBackground(ProductionAlertSeverity severity) => switch (severity) {
        ProductionAlertSeverity.critical => const Color(0xFFFFF1F2),
        ProductionAlertSeverity.warning => const Color(0xFFFFF7ED),
        ProductionAlertSeverity.info => const Color(0xFFF8FAFC),
      };

  static Color _alertForeground(ProductionAlertSeverity severity) => switch (severity) {
        ProductionAlertSeverity.critical => AppTheme.danger,
        ProductionAlertSeverity.warning => AppTheme.warning,
        ProductionAlertSeverity.info => AppTheme.text,
      };
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final ProductionOrderSummary order;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.number, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${order.product} • ${order.line}', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 6),
              Text('${order.completed} / ${order.planned} units', style: const TextStyle(fontSize: 12)),
            ])),
            _ProductionStatus(label: order.status),
          ]),
        ),
      );
}

class _ProductionStatus extends StatelessWidget {
  const _ProductionStatus({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final warning = label == 'Material Pending';
    final success = label == 'Completed';
    final color = success ? AppTheme.success : warning ? AppTheme.warning : AppTheme.brand;
    final background = success ? const Color(0xFFECFDF3) : warning ? const Color(0xFFFFF7ED) : const Color(0xFFE7EEFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
