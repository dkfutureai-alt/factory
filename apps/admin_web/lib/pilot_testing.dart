import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pilot_coverage.dart';

class PilotTestingPage extends StatefulWidget {
  const PilotTestingPage({required this.organizationId, super.key});
  final String organizationId;

  @override
  State<PilotTestingPage> createState() => _PilotTestingPageState();
}

class _PilotTestingPageState extends State<PilotTestingPage> {
  late Future<_PilotSnapshot> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void _reload() => setState(() => future = _load());

  Future<_PilotSnapshot> _load() async {
    final client = Supabase.instance.client;
    final testers = await client
        .from('pilot_participants')
        .select('user_id,consented_at')
        .eq('organization_id', widget.organizationId)
        .order('consented_at', ascending: false);
    final feedback = await client
        .from('pilot_feedback')
        .select('id,user_id,scenario,result,notes,created_at')
        .eq('organization_id', widget.organizationId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(250);
    final membership = await client.rpc(
      'list_organization_members',
      params: {'p_organization_id': widget.organizationId},
    );
    final names = <String, String>{};
    for (final row in membership as List<dynamic>) {
      final member = Map<String, dynamic>.from(row as Map);
      final userId = member['user_id'] as String;
      final fullName = (member['full_name'] as String? ?? '').trim();
      names[userId] = fullName.isNotEmpty
          ? fullName
          : member['email'] as String? ?? 'Tester';
    }
    return _PilotSnapshot(
      testers: List<Map<String, dynamic>>.from(testers),
      feedback: List<Map<String, dynamic>>.from(feedback),
      names: names,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PilotSnapshot>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilot testing is not yet available.'),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        );
      }
      final pilot = snapshot.requireData;
      final coverage = PilotCoverageSummary.fromRecentFeedback(pilot.feedback);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Customer pilot testing',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Invite consenting customers through Users. Each person must '
            'accept their invitation and opt in from Profile in the mobile app. '
            'Admins cannot join the pilot on behalf of a tester.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(label: 'Joined testers', count: pilot.testers.length),
              _Metric(label: 'Pass-reported scenarios', count: coverage.passedScenarios),
              _Metric(label: 'Scenarios with failures', count: coverage.failedScenarios),
              _Metric(label: 'Scenarios blocked', count: coverage.blockedScenarios),
              _Metric(label: 'No recent evidence', count: coverage.unreportedScenarios),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'These results use each tester\'s latest report for each workflow, '
            'rather than counting historical passes. A failure or blocker '
            'reported by any tester takes priority. Feedback is not release approval.',
          ),
          const SizedBox(height: 12),
          Text('Workflow coverage', style: Theme.of(context).textTheme.titleLarge),
          if (coverage.isHistoryLimited)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Only the latest 250 entries are loaded. Older test reports '
                'may be excluded. Do not use this limited view to approve release.',
              ),
            ),
          for (final scenario in coverage.scenarios)
            ListTile(
              dense: true,
              leading: Icon(switch (scenario.status) {
                PilotScenarioStatus.failed => Icons.error_outline,
                PilotScenarioStatus.blocked => Icons.pause_circle_outline,
                PilotScenarioStatus.passReported => Icons.check_circle_outline,
                PilotScenarioStatus.notReported => Icons.radio_button_unchecked,
              }),
              title: Text(scenario.label),
              subtitle: Text(
                '${scenario.testersReporting} tester reports in recent sample',
              ),
              trailing: Text(switch (scenario.status) {
                PilotScenarioStatus.failed => 'Failed',
                PilotScenarioStatus.blocked => 'Blocked',
                PilotScenarioStatus.passReported => 'Pass reported',
                PilotScenarioStatus.notReported => 'Not reported',
              }),
            ),
          const SizedBox(height: 16),
          Text('Consenting customers', style: Theme.of(context).textTheme.titleLarge),
          if (pilot.testers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No real testers have opted in yet. '
                  'Use Users to invite consenting customer representatives.',
                ),
              ),
            ),
          for (final tester in pilot.testers)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(pilot.names[tester['user_id']] ?? 'Tester'),
                subtitle: Text(
                  'Consent recorded: ${tester['consented_at']}',
                ),
                trailing: Text(
                  '${pilot.feedback.where((r) => r['user_id'] == tester['user_id']).length} recent reports',
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Recent test feedback (up to 250)', style: Theme.of(context).textTheme.titleLarge),
          for (final report in pilot.feedback)
            Card(
              child: ListTile(
                leading: Icon(switch (report['result']) {
                  'passed' => Icons.check_circle_outline,
                  'failed' => Icons.error_outline,
                  _ => Icons.pause_circle_outline,
                }),
                title: Text(
                  '${report['scenario']} · ${report['result']}',
                ),
                subtitle: Text(
                  '${pilot.names[report['user_id']] ?? 'Tester'} · ${report['notes'] ?? ''}',
                ),
              ),
            ),
          if (pilot.feedback.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No reports submitted. Zero passes are assumed.'),
            ),
          const SizedBox(height: 20),
          const Text(
            'A tester-reported pass does not grant production release approval. '
            'Review role isolation, inventory correctness and security separately.',
          ),
        ],
      );
    },
  );

}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
}

class _PilotSnapshot {
  const _PilotSnapshot({
    required this.testers,
    required this.feedback,
    required this.names,
  });
  final List<Map<String, dynamic>> testers;
  final List<Map<String, dynamic>> feedback;
  final Map<String, String> names;
}
