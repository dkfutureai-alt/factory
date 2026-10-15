import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class OperationsReportPage extends StatelessWidget {
  const OperationsReportPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Operations Report', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<OperationsReport>(
          future: repository.loadOperations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load operations report.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              ReportPageHeader(title: 'Production, quality, inventory & maintenance', subtitle: '${data.filter.factoryName} • ${data.filter.inclusiveDays} days'),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                ReportMetricCard(label: 'Production output', value: '${data.productionOutput} pcs'),
                ReportMetricCard(label: 'First-pass quality', value: percent(data.firstPassQuality), accent: AppTheme.success),
                ReportMetricCard(label: 'Low-stock items', value: '${data.lowStockItems}', accent: AppTheme.warning),
                ReportMetricCard(label: 'Downtime', value: '${data.downtimeHours.toStringAsFixed(1)} h'),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final performance = ReportSection(title: 'Line performance', child: Column(children: data.linePerformance.keys.map((line) => RateBarRow(label: line, rate: data.lineRate(line))).toList()));
                final inventory = ReportSection(title: 'Inventory health', child: Column(children: [
                  _ValueRow('Raw material', moneyLakhs(data.rawMaterialValue)),
                  _ValueRow('Finished goods', moneyLakhs(data.finishedGoodsValue)),
                  _ValueRow('Spares', moneyLakhs(data.sparesValue)),
                  const Divider(),
                  _ValueRow('Total inventory', moneyLakhs(data.inventoryValue), strong: true),
                ]));
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: performance), const SizedBox(width: 16), Expanded(flex: 2, child: inventory)]);
                return Column(children: [performance, const SizedBox(height: 16), inventory]);
              }),
              const SizedBox(height: 18),
              ReportSection(title: 'Operational exceptions', child: Column(children: data.exceptions.map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.report_problem_outlined, color: AppTheme.warning), title: Text(item))).toList())),
            ]);
          },
        ),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w400))), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}
