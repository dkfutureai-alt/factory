import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reporting_repository.dart';
import '../domain/reporting_models.dart';
import 'reporting_widgets.dart';

class WorkforceFleetReportPage extends StatelessWidget {
  const WorkforceFleetReportPage({super.key, required this.repository});
  final ReportingRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Workforce & Fleet Report', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<WorkforceFleetReport>(
          future: repository.loadWorkforceFleet(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load workforce and fleet report.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              ReportPageHeader(title: 'People and transport performance', subtitle: '${data.filter.factoryName} • ${data.filter.inclusiveDays} days'),
              const SizedBox(height: 18),
              Wrap(spacing: 14, runSpacing: 14, children: [
                ReportMetricCard(label: 'Attendance rate', value: percent(data.attendanceRate), accent: AppTheme.success),
                ReportMetricCard(label: 'On leave today', value: '${data.onLeaveToday}'),
                ReportMetricCard(label: 'Fleet availability', value: percent(data.fleetAvailability), accent: AppTheme.success),
                ReportMetricCard(label: 'Average mileage', value: '${data.averageMileage.toStringAsFixed(1)} km/L'),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final attendance = ReportSection(title: 'Department attendance', child: Column(children: data.departmentAttendance.map((row) => RateBarRow(label: row.department, rate: row.boundedRate)).toList()));
                final fleet = ReportSection(title: 'Fleet health', child: Column(children: [
                  _ValueRow('Vehicles active', '${data.availableVehicles} / ${data.totalVehicles}'),
                  _ValueRow('Trips completed', '${data.tripsCompleted}'),
                  _ValueRow('Fuel consumed', '${data.fuelConsumedLitres.toStringAsFixed(0)} L'),
                  _ValueRow('Service alerts', '${data.serviceAlerts}', warning: data.serviceAlerts > 0),
                ]));
                if (box.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: attendance), const SizedBox(width: 16), Expanded(flex: 2, child: fleet)]);
                return Column(children: [attendance, const SizedBox(height: 16), fleet]);
              }),
              const SizedBox(height: 18),
              ReportSection(title: 'People & transport exceptions', child: Column(children: data.exceptions.map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.info_outline, color: AppTheme.warning), title: Text(item))).toList())),
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
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: warning ? AppTheme.warning : AppTheme.text))]),
      );
}
