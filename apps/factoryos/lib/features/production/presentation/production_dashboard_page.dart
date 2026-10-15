import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/production_order_detail_repository.dart';
import '../data/production_repository.dart';
import '../domain/production_models.dart';
import 'production_order_detail_page.dart';

class ProductionDashboardPage extends StatelessWidget {
  const ProductionDashboardPage({
    super.key,
    required this.repository,
    this.detailRepository,
  });

  final ProductionRepository repository;
  final ProductionOrderDetailRepository? detailRepository;

  void _openOrder(BuildContext context, String orderNumber) {
    final detail = detailRepository;
    if (detail == null) {
      Navigator.of(context).pushNamed('/production/order');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductionOrderDetailPage(
          repository: detail,
          orderNumber: orderNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Production', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Main Manufacturing Plant • Current operations', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
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
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Current production position', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _Metric(label: 'Planned quantity', value: '${data.plannedQuantity}'),
                    _Metric(label: 'Completed', value: '${data.completedQuantity}', accent: AppTheme.success),
                    _Metric(label: 'In production', value: '${data.activeOrderCount}', accent: AppTheme.brand),
                    _Metric(label: 'Rejected / hold', value: '${data.rejectedOrHoldQuantity}', accent: AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth > 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _Progress(data: data)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _Alerts(
                                alerts: data.alerts,
                                onOpenOrder: (number) => _openOrder(context, number),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _Progress(data: data),
                            const SizedBox(height: 16),
                            _Alerts(
                              alerts: data.alerts,
                              onOpenOrder: (number) => _openOrder(context, number),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active production orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ...data.orders.map(
                          (order) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _openOrder(context, order.number),
                            title: Text(order.number, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${order.product} • ${order.line} • ${order.completed}/${order.planned}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Status(label: order.status),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
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

class _Progress extends StatelessWidget {
  const _Progress({required this.data});
  final ProductionOverview data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Production progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: data.achievement.clamp(0, 1),
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 12),
              Text('${(data.achievement * 100).toStringAsFixed(1)}% completed', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.alerts, required this.onOpenOrder});
  final List<ProductionAlert> alerts;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attention required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No active production alerts.', style: TextStyle(color: AppTheme.muted)),
                ),
              ...alerts.map(
                (alert) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: alert.title.startsWith('PRD-') ? () => onOpenOrder(alert.title) : null,
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(alert.detail),
                  trailing: alert.title.startsWith('PRD-') ? const Icon(Icons.chevron_right) : null,
                  leading: Icon(
                    alert.severity == ProductionAlertSeverity.critical
                        ? Icons.error_outline
                        : alert.severity == ProductionAlertSeverity.warning
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                    color: alert.severity == ProductionAlertSeverity.critical
                        ? AppTheme.danger
                        : alert.severity == ProductionAlertSeverity.warning
                            ? AppTheme.warning
                            : AppTheme.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final warning = label == 'Material Pending';
    final color = warning ? AppTheme.warning : AppTheme.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFE7EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
