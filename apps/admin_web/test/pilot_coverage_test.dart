import 'package:factoryos_admin_web/pilot_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> report(
  String user,
  String scenario,
  String result, {
  String id = '00000000-0000-4000-8000-000000000001',
  String at = '2026-10-28T10:00:00Z',
}) => {
  'id': id,
  'user_id': user,
  'scenario': scenario,
  'result': result,
  'created_at': at,
};

void main() {
  test('empty pilot shows no verified passes', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([]);
    expect(summary.scenarios.length, pilotScenarioLabels.length);
    expect(summary.unreportedScenarios, pilotScenarioLabels.length);
    expect(summary.passedScenarios, 0);
    expect(summary.isHistoryLimited, isFalse);
  });

  test('latest result supersedes old failure for the same tester', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'inventory', 'failed', at: '2026-10-28T11:00:00Z'),
      report('alice', 'inventory', 'passed', at: '2026-10-28T12:00:00Z'),
      report('alice', 'inventory', 'passed', at: '2026-10-28T09:00:00Z'),
    ]);
    final item = summary.scenarios.singleWhere((s) => s.key == 'inventory');
    expect(item.status, PilotScenarioStatus.passReported);
    expect(item.testersReporting, 1);
  });

  test('a different tester failure overrides another tester pass', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'production', 'passed'),
      report('bob', 'production', 'failed'),
      report('carol', 'production', 'blocked'),
    ]);
    final item = summary.scenarios.singleWhere((s) => s.key == 'production');
    expect(item.status, PilotScenarioStatus.failed);
    expect(item.testersReporting, 3);
    expect(summary.passedScenarios, 0);
  });

  test('blocked reports are not counted as passes', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'hr', 'passed'),
      report('bob', 'hr', 'blocked'),
    ]);
    expect(summary.blockedScenarios, 1);
    expect(summary.passedScenarios, 0);
  });

  test('equal timestamp uses stable ID tie breaker', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'fleet', 'failed', id: 'a'),
      report('alice', 'fleet', 'passed', id: 'b'),
    ]);
    expect(
      summary.scenarios.singleWhere((s) => s.key == 'fleet').status,
      PilotScenarioStatus.passReported,
    );
  });

  test('unknown scenarios and invalid reporters are ignored', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'unknown', 'passed'),
      {...report('alice', 'quality', 'passed'), 'user_id': null},
    ]);
    expect(summary.passedScenarios, 0);
  });

  test('report query cap marks the view as incomplete', () {
    final summary = PilotCoverageSummary.fromRecentFeedback(
      [report('alice', 'security', 'passed')],
      limit: 1,
    );
    expect(summary.isHistoryLimited, isTrue);
    expect(summary.unreportedScenarios, pilotScenarioLabels.length - 1);
  });

  test('newer failure supersedes an older reported pass', () {
    final summary = PilotCoverageSummary.fromRecentFeedback([
      report('alice', 'delivery', 'passed', at: '2026-10-28T09:00:00Z'),
      report('alice', 'delivery', 'failed', at: '2026-10-28T11:00:00Z'),
    ]);
    expect(
      summary.scenarios.singleWhere((s) => s.key == 'delivery').status,
      PilotScenarioStatus.failed,
    );
  });
}
