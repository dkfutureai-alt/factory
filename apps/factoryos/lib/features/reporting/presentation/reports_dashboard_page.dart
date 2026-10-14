import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class ReportsDashboardPage extends StatelessWidget {
  const ReportsDashboardPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<ReportsOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load reporting overview.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              ReportPageHeader(
                title: 'Reports Center',
                subtitle: '${data.filter.factoryName} • ${data.filter.inclusiveDays} day reporting window • Preview analytics',
                actions: [OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/reports/builder'), icon: const Icon(Icons.file_download_outlined), label: const Text('Build export'))],
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                ReportMetricCard(label: 'Production achievement', value: percent(data.boundedProductionAchievement), accent: AppTheme.success),
                ReportMetricCard(label: 'Inventory value', value: moneyLakhs(data.inventoryValue)),
                ReportMetricCard(label: 'Sales this month', value: moneyLakhs(data.salesThisMonth)),
                ReportMetricCard(label: 'Attendance rate', value: percent(data.boundedAttendanceRate), accent: AppTheme.success),
              ]),
              const SizedBox(height: 18),
              ReportSection(title: 'Report library', child: Wrap(spacing: 12, runSpacing: 12, children: [
                _ReportTile(title: 'Executive Analytics', subtitle: 'Cross-module KPI scorecard', icon: Icons.analytics_outlined, route: '/reports/executive'),
                _ReportTile(title: 'Operations', subtitle: 'Production, quality, inventory, maintenance', icon: Icons.precision_manufacturing_outlined, route: '/reports/operations'),
                _ReportTile(title: 'Commercial', subtitle: 'Sales, collections and purchase', icon: Icons.currency_rupee_outlined, route: '/reports/commercial'),
                _ReportTile(title: 'Workforce & Fleet', subtitle: 'Attendance, vehicles, trips and fuel', icon: Icons.groups_2_outlined, route: '/reports/workforce-fleet'),
                _ReportTile(title: 'Report Builder', subtitle: 'Scope, metrics and export format', icon: Icons.tune_outlined, route: '/reports/builder'),
              ])),
              const SizedBox(height: 18),
              ReportSection(
                title: 'Performance trend',
                child: SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.trend.map((point) {
                      final height = (point.value.clamp(0, 100) / 100) * 120;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(point.value.toStringAsFixed(0), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                            const SizedBox(height: 4),
                            Container(height: height, decoration: BoxDecoration(color: AppTheme.brand.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 6),
                            Text(point.label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.title, required this.subtitle, required this.icon, required this.route});
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        height: 132,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pushNamed(route),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE4E9F1)), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: AppTheme.brand),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            ]),
          ),
        ),
      );
}
