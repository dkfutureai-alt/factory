import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class ReportBuilderPage extends StatefulWidget {
  const ReportBuilderPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  State<ReportBuilderPage> createState() => _ReportBuilderPageState();
}

class _ReportBuilderPageState extends State<ReportBuilderPage> {
  String reportType = 'Executive Analytics';
  ReportExportFormat format = ReportExportFormat.pdf;
  final selected = <String>{'Production', 'Inventory', 'Sales & collections', 'Attendance', 'Fleet & maintenance'};
  ReportPreview? preview;

  ReportFilter get filter => PreviewReportingRepository.demoFilter;

  Future<void> _buildPreview() async {
    final result = await widget.repository.buildPreview(ReportBuildRequest(
      reportType: reportType,
      filter: filter,
      metrics: selected.toList(),
      format: format,
    ));
    if (!mounted) return;
    setState(() => preview = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Report Builder', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const ReportPageHeader(title: 'Build an export-ready report', subtitle: 'Select scope and metrics. Preview mode never changes operational records.'),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final config = ReportSection(title: 'Report configuration', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                initialValue: reportType,
                decoration: const InputDecoration(labelText: 'Report type'),
                items: const ['Executive Analytics', 'Operations', 'Commercial', 'Workforce & Fleet'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (value) => setState(() => reportType = value ?? reportType),
              ),
              const SizedBox(height: 16),
              Text('Date range: 01 Oct 2026 – 14 Oct 2026', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Factory: ${filter.factoryName}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              const Text('Metrics', style: TextStyle(fontWeight: FontWeight.w800)),
              ...['Production', 'Inventory', 'Sales & collections', 'Attendance', 'Fleet & maintenance'].map((metric) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(metric),
                title: Text(metric),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    selected.add(metric);
                  } else {
                    selected.remove(metric);
                  }
                }),
              )),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReportExportFormat>(
                initialValue: format,
                decoration: const InputDecoration(labelText: 'Export format'),
                items: const [
                  DropdownMenuItem(value: ReportExportFormat.pdf, child: Text('PDF')),
                  DropdownMenuItem(value: ReportExportFormat.csv, child: Text('CSV')),
                  DropdownMenuItem(value: ReportExportFormat.excel, child: Text('Excel')),
                ],
                onChanged: (value) => setState(() => format = value ?? format),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: selected.isEmpty ? null : _buildPreview, icon: const Icon(Icons.visibility_outlined), label: const Text('Generate preview')),
            ]));

            final exportPreview = ReportSection(title: 'Export preview', child: preview == null
                ? const SizedBox(height: 430, child: Center(child: Text('Choose metrics and generate a preview.', style: TextStyle(color: AppTheme.muted))))
                : _PreviewBody(preview!));
            if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 430, child: config), const SizedBox(width: 16), Expanded(child: exportPreview)]);
            return Column(children: [config, const SizedBox(height: 16), exportPreview]);
          }),
        ]),
      );
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody(this.preview);
  final ReportPreview preview;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(preview.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${preview.filter.factoryName} • ${preview.filter.inclusiveDays} days', style: const TextStyle(color: AppTheme.muted)),
        const Divider(height: 30),
        ...preview.metrics.map((metric) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: metric.supporting.isEmpty ? null : Text(metric.supporting),
          trailing: Text(metric.value, style: const TextStyle(fontWeight: FontWeight.w800)),
        )),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4E9F1))),
          child: const Text('Export foundation only: PDF/CSV/Excel file generation is intentionally not connected until production repositories and server-side export rules are available.', style: TextStyle(color: AppTheme.muted)),
        ),
      ]);
}
