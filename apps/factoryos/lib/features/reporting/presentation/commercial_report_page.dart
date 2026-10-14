import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class CommercialReportPage extends StatelessWidget {
  const CommercialReportPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Commercial Report', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<CommercialReport>(
          future: repository.loadCommercial(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load commercial report.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              ReportPageHeader(title: 'Sales, collections & purchase', subtitle: '${data.filter.factoryName} • ${data.filter.inclusiveDays} days'),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                ReportMetricCard(label: 'Sales booked', value: moneyLakhs(data.salesBooked)),
                ReportMetricCard(label: 'Collected', value: moneyLakhs(data.collected), supporting: percent(data.collectionRate), accent: AppTheme.success),
                ReportMetricCard(label: 'Receivable', value: moneyLakhs(data.receivable), accent: AppTheme.warning),
                ReportMetricCard(label: 'Purchase open', value: moneyLakhs(data.purchaseOpen)),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final orderHealth = ReportSection(title: 'Order health', child: Column(children: [
                  _ValueRow('Open sales orders', '${data.openSalesOrders}'),
                  _ValueRow('Ready for dispatch', '${data.readyForDispatch}'),
                  _ValueRow('Overdue receivables', moneyLakhs(data.overdueReceivables), warning: true),
                  _ValueRow('POs due this week', '${data.purchaseOrdersDue}'),
                ]));
                final collection = ReportSection(title: 'Collection performance', child: Column(children: [
                  RateBarRow(label: 'Collection', rate: data.collectionRate),
                  const SizedBox(height: 8),
                  const Text('Collections are derived from received payment records; preview does not post financial transactions.', style: TextStyle(color: AppTheme.muted)),
                ]));
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: collection), const SizedBox(width: 16), Expanded(child: orderHealth)]);
                return Column(children: [collection, const SizedBox(height: 16), orderHealth]);
              }),
              const SizedBox(height: 18),
              ReportSection(title: 'Top customer performance', child: Column(children: data.customers.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(row.customer, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(child: Text(moneyLakhs(row.sales), textAlign: TextAlign.right)),
                  Expanded(child: Text(moneyLakhs(row.collected), textAlign: TextAlign.right)),
                  Expanded(child: Text(moneyLakhs(row.outstanding), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
              )).toList())),
            ]);
          },
        ),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value, {this.warning = false});
  final String label;
  final String value;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: warning ? AppTheme.danger : AppTheme.text))]),
      );
}
