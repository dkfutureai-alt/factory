import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        .select('user_id,scenario,result,notes,created_at')
        .eq('organization_id', widget.organizationId)
        .order('created_at', ascending: false)
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
      final passed = pilot.feedback.where((r) => r['result'] == 'passed').length;
      final failed = pilot.feedback.where((r) => r['result'] == 'failed').length;
      final blocked = pilot.feedback.where((r) => r['result'] == 'blocked').length;
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
              _Metric(label: 'Passed reports', count: passed),
              _Metric(label: 'Failed reports', count: failed),
              _Metric(label: 'Blocked reports', count: blocked),
            ],
          ),
          const SizedBox(height: 20),
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
                  'Consent recorded: ' + (tester['consented_at'] as String),
                ),
                trailing: Text(
                  pilot.feedback
                      .where((r) => r['user_id'] == tester['user_id'])
                      .length
                      .toString() + ' reports',
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Recent test feedback', style: Theme.of(context).textTheme.titleLarge),
          for (final report in pilot.feedback)
            Card(
              child: ListTile(
                leading: Icon(switch (report['result']) {
                  'passed' => Icons.check_circle_outline,
                  'failed' => Icons.error_outline,
                  _ => Icons.pause_circle_outline,
                }),
                title: Text(
                  (report['scenario'] as String) +
                  ' · ' +
                  (report['result'] as String),
                ),
                subtitle: Text(
                  (pilot.names[report['user_id']] ?? 'Tester') +
                  ' · ' +
                  (report['notes'] as String? ?? ''),
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
