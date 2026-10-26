import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const pilotScenarios = <String, String>{
  'onboarding': 'Account & onboarding',
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

class CustomerPilotPage extends StatefulWidget {
  const CustomerPilotPage({required this.organizationId, super.key});
  final String organizationId;

  @override
  State<CustomerPilotPage> createState() => _CustomerPilotPageState();
}

class _CustomerPilotPageState extends State<CustomerPilotPage> {
  late Future<_PilotSnapshot> future;
  final notes = TextEditingController();
  bool consent = false;
  bool busy = false;
  String scenario = 'onboarding';
  String result = 'passed';
  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<_PilotSnapshot> _load() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to join the customer pilot.');
    final membership = await client
        .from('pilot_participants')
        .select('consented_at')
        .eq('organization_id', widget.organizationId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (membership == null) {
      return const _PilotSnapshot(joined: false, reports: []);
    }
    final reports = await client
        .from('pilot_feedback')
        .select('scenario,result,notes,created_at')
        .eq('organization_id', widget.organizationId)
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return _PilotSnapshot(
      joined: true,
      reports: List<Map<String, dynamic>>.from(reports),
    );
  }

  void _reload() => setState(() => future = _load());

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save pilot feedback: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    if (!consent) return;
    await _perform(() async {
      await client.from('pilot_participants').insert({
        'organization_id': widget.organizationId,
        'user_id': client.auth.currentUser!.id,
      });
    });
  }

  Future<void> _report() async {
    await _perform(() async {
      await client.from('pilot_feedback').insert({
        'organization_id': widget.organizationId,
        'user_id': client.auth.currentUser!.id,
        'scenario': scenario,
        'result': result,
        'notes': notes.text.trim(),
      });
      notes.clear();
    });
  }

  Future<void> _withdraw() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave customer pilot?'),
        content: const Text(
          'All your pilot feedback will be deleted. Your normal '
          'FactoryOS account and factory data stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep participating'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave and erase feedback'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await _perform(() async {
      await client
          .from('pilot_participants')
          .delete()
          .eq('organization_id', widget.organizationId)
          .eq('user_id', client.auth.currentUser!.id);
      if (mounted) setState(() => consent = false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer pilot')),
    body: FutureBuilder<_PilotSnapshot>(
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
                const Text('Pilot testing is not configured for this workspace yet.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final pilot = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              pilot.joined ? 'Report test results' : 'Join the customer pilot',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Only test authorized workflows. Do not include customer names, '
              'passwords, or confidential factory data in feedback.',
            ),
            const SizedBox(height: 20),
            if (!pilot.joined) ...[
              const Text(
                'Joining is voluntary. Your organization admin can see the '
                'testing status, results and comments. You may leave at '
                'any time and erase all these pilot records.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy
                    ? null
                    : (value) => setState(() => consent = value ?? false),
                title: const Text('I agree to join this test'),
              ),
              FilledButton(
                onPressed: busy || !consent ? null : _join,
                child: const Text('Join customer pilot'),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Submit a test result',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: scenario,
                        decoration: const InputDecoration(labelText: 'Scenario'),
                        items: pilotScenarios.entries
                            .map((entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) => setState(() => scenario = value ?? scenario),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: result,
                        decoration: const InputDecoration(labelText: 'Result'),
                        items: const [
                          DropdownMenuItem(value: 'passed', child: Text('Passed')),
                          DropdownMenuItem(value: 'failed', child: Text('Failed')),
                          DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => result = value ?? result),
                      ),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Describe what worked or blocked you',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: busy ? null : _report,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Submit result'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('My recent results', style: Theme.of(context).textTheme.titleMedium),
              if (pilot.reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No results submitted yet.'),
                ),
              for (final report in pilot.reports)
                Card(
                  child: ListTile(
                    leading: Icon(switch (report['result']) {
                      'passed' => Icons.check_circle_outline,
                      'failed' => Icons.error_outline,
                      _ => Icons.pause_circle_outline,
                    }),
                    title: Text(pilotScenarios[report['scenario']] ?? 'Test'),
                    subtitle: Text(
                      (report['result'] as String) +
                      ' · ' +
                      (report['notes'] as String? ?? ''),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: busy ? null : _withdraw,
                child: const Text('Leave pilot and erase my reports'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _PilotSnapshot {
  const _PilotSnapshot({required this.joined, required this.reports});
  final bool joined;
  final List<Map<String, dynamic>> reports;
}
