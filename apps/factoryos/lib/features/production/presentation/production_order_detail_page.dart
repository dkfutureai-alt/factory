import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/production_order_detail_repository.dart';

class ProductionOrderDetailPage extends StatelessWidget {
  const ProductionOrderDetailPage({
    super.key,
    required this.repository,
    required this.orderNumber,
  });

  final ProductionOrderDetailRepository repository;
  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(orderNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<ProductionOrderDetail>(
        future: repository.loadOrder(orderNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load production order.'));
          }
          final detail = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('${detail.product} • ${detail.line}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Plan', value: '${detail.planned} units'),
                  _Metric(label: 'Completed', value: '${detail.completed} units', accent: AppTheme.brand),
                  _Metric(label: 'Start', value: detail.startedAt),
                  _Metric(label: 'Due', value: detail.dueAt),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final materials = _Materials(detail: detail);
                  final batchQc = _BatchQc(detail: detail);
                  if (constraints.maxWidth > 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: materials),
                        const SizedBox(width: 16),
                        Expanded(child: batchQc),
                      ],
                    );
                  }
                  return Column(children: [materials, const SizedBox(height: 16), batchQc]);
                },
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Execution timeline', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ...detail.timeline.map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            event.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: event.isWarning ? AppTheme.warning : AppTheme.brand,
                          ),
                          title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(event.detail),
                          trailing: Text(event.time, style: const TextStyle(color: AppTheme.muted)),
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
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              Text(value, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Materials extends StatelessWidget {
  const _Materials({required this.detail});
  final ProductionOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Material requirement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...detail.materials.map(
              (material) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(material.sku, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(material.name),
                trailing: Text(
                  material.shortage > 0
                      ? 'Short ${material.shortage.toStringAsFixed(0)} ${material.unit}'
                      : 'Ready',
                  style: TextStyle(
                    color: material.shortage > 0 ? AppTheme.warning : AppTheme.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchQc extends StatelessWidget {
  const _BatchQc({required this.detail});
  final ProductionOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Batch & QC', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            const Text('Active batch', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            Text(detail.batchNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 18),
            const Text('Quality', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            Text(detail.qcStatus, style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Text('${detail.rejected} rejected units', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
