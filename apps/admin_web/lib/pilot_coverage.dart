/// Voluntary feedback summary, not independent release acceptance.
const pilotScenarioLabels = <String, String>{
  'onboarding': 'Onboarding & sign-in',
  'hr': 'HR & attendance',
  'inventory': 'Inventory & scanning',
  'production': 'Production',
  'quality': 'Quality inspection',
  'purchasing': 'Purchasing',
  'sales': 'Sales',
  'warehouse': 'Warehouse',
  'fleet': 'Fleet & fuel',
  'delivery': 'Delivery & POD',
  'maintenance': 'Maintenance',
  'reports': 'Reports',
  'notifications': 'Notifications',
  'security': 'Access & security',
};

enum PilotScenarioStatus { notReported, passReported, failed, blocked }

class PilotScenarioCoverage {
  const PilotScenarioCoverage(this.key, this.label, this.status, this.testersReporting);
  final String key;
  final String label;
  final PilotScenarioStatus status;
  final int testersReporting;
}

class PilotCoverageSummary {
  const PilotCoverageSummary(this.scenarios, this.recentReportCount, this.isHistoryLimited);
  final List<PilotScenarioCoverage> scenarios;
  final int recentReportCount;
  final bool isHistoryLimited;

  int get passedScenarios =>
      scenarios.where((s) => s.status == PilotScenarioStatus.passReported).length;
  int get failedScenarios =>
      scenarios.where((s) => s.status == PilotScenarioStatus.failed).length;
  int get blockedScenarios =>
      scenarios.where((s) => s.status == PilotScenarioStatus.blocked).length;
  int get unreportedScenarios =>
      scenarios.where((s) => s.status == PilotScenarioStatus.notReported).length;

  factory PilotCoverageSummary.fromRecentFeedback(
    List<Map<String, dynamic>> feedback, {
    int limit = 250,
  }) {
    final latest = <String, Map<String, dynamic>>{};
    for (final report in feedback) {
      final user = report['user_id'];
      final scenario = report['scenario'];
      if (user is! String ||
          user.isEmpty ||
          scenario is! String ||
          !pilotScenarioLabels.containsKey(scenario)) {
        continue;
      }
      final key = '$user:$scenario';
      final previous = latest[key];
      if (previous == null || _isNewer(report, previous)) {
        latest[key] = report;
      }
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final report in latest.values) {
      grouped.putIfAbsent(report['scenario'] as String, () => []).add(report);
    }
    final scenarios = <PilotScenarioCoverage>[];
    for (final entry in pilotScenarioLabels.entries) {
      final reports = grouped[entry.key] ?? [];
      final status = reports.isEmpty
          ? PilotScenarioStatus.notReported
          : reports.any((r) => r['result'] == 'failed')
              ? PilotScenarioStatus.failed
              : reports.any((r) => r['result'] == 'blocked')
                  ? PilotScenarioStatus.blocked
                  : reports.every((r) => r['result'] == 'passed')
                      ? PilotScenarioStatus.passReported
                      : PilotScenarioStatus.notReported;
      scenarios.add(PilotScenarioCoverage(
        entry.key, entry.value, status, reports.length,
      ));
    }
    return PilotCoverageSummary(
      List.unmodifiable(scenarios), feedback.length, feedback.length >= limit,
    );
  }
}

bool _isNewer(Map<String, dynamic> candidate, Map<String, dynamic> older) {
  DateTime parse(Map<String, dynamic> row) =>
      DateTime.tryParse(row['created_at']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final compared = parse(candidate).compareTo(parse(older));
  if (compared != 0) return compared > 0;
  return (candidate['id']?.toString() ?? '')
          .compareTo(older['id']?.toString() ?? '') > 0;
}
