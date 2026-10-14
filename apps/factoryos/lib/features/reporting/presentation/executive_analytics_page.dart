import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class ExecutiveAnalyticsPage extends StatelessWidget {
  const ExecutiveAnalyticsPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Executive Analytics', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<ExecutiveAnalyticsReport>(
          future: repository.loadExecutive(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load executive analytics.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              ReportPageHeader(
                title: 'Cross-module performance',
                subtitle: '${data.filter.factoryName} • ${data.filter.inclusiveDays} days',
                actions: [OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/reports/builder'), icon: const Icon(Icons.download_outlined), label: const Text('Export'))],
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                ReportMetricCard(label: 'Revenue', value: moneyLakhs(data.revenue)),
                ReportMetricCard(label: 'Production', value: percent(data.boundedRate(data.productionAchievement)), accent: AppTheme.success),
                ReportMetricCard(label: 'On-time delivery', value: percent(data.boundedRate(data.onTimeDeliveryRate))),
                ReportMetricCard(label: 'Attendance', value: percent(data.boundedRate(data.attendanceRate)), accent: AppTheme.success),
                ReportMetricCard(label: 'Asset availability', value: percent(data.boundedRate(data.assetAvailability))),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final trend = ReportSection(title: 'Business trend', child: Column(children: data.trend.map((point) => RateBarRow(label: point.label, rate: point.value / 100)).toList()));
                final attention = ReportSection(title: 'Management attention', child: Column(children: data.attentionItems.map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning), title: Text(item))).toList()));
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: trend), const SizedBox(width: 16), Expanded(flex: 2, child: attention)]);
                return Column(children: [trend, const SizedBox(height: 16), attention]);
              }),
              const SizedBox(height: 18),
              ReportSection(title: 'Module scorecard', child: Column(children: data.scorecard.map((row) => _ScoreRow(row)).toList())),
            ]);
          },
        ),
      );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.row);
  final ReportScorecardRow row;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 140, child: Text(row.area, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(row.kpi)),
          SizedBox(width: 90, child: Text(row.current, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(width: 90, child: Text(row.target, textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.muted))),
          SizedBox(width: 100, child: Text(row.status, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: row.status == 'On track' ? AppTheme.success : AppTheme.warning))),
        ]),
      );
}
