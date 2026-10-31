import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform-owner-only release settings. RLS independently enforces all writes.
class MobileReleaseManagementPage extends StatefulWidget {
  const MobileReleaseManagementPage({super.key});

  @override
  State<MobileReleaseManagementPage> createState() =>
      _MobileReleaseManagementPageState();
}

class _MobileReleaseManagementPageState
    extends State<MobileReleaseManagementPage> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('mobile_release_policies')
        .select()
        .order('application_id')
        .order('platform');
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _edit([Map<String, dynamic>? previous]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReleasePolicyEditor(initial: previous),
    );
    if (result == null || !mounted) return;
    try {
      await Supabase.instance.client.from('mobile_release_policies').upsert(
        result,
        onConflict: 'application_id,platform',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App release policy saved.')),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save release policy. Check permissions and retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('App version policies'),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Refresh app policies',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('New policy'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return FactoryStatePanel(
                  state: FactoryViewState.error,
                  message: 'Cannot load app release policies. Verify the reviewed migration and permissions.',
                  onRetry: _reload,
                );
              }
              return const FactoryStatePanel(
                state: FactoryViewState.loading,
                message: 'Loading app policies…',
              );
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return const FactoryStatePanel(
                state: FactoryViewState.empty,
                message: 'No app release policy yet. Create and publish a policy for each registered mobile app.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final active = row['enabled'] == true;
                final maintenance = row['maintenance_mode'] == true;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(FactorySpacing.md),
                    leading: Icon(
                      maintenance ? Icons.construction : Icons.system_update_alt,
                    ),
                    title: Text('${row['application_id']} · ${row['platform']}'),
                    subtitle: Text(
                      'Minimum ${row['minimum_version']} · Latest ${row['latest_version']}\n'
                      '${active ? 'Published' : 'Draft'}'
                      '${maintenance ? ' · Maintenance ON' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(row),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _ReleasePolicyEditor extends StatefulWidget {
  const _ReleasePolicyEditor({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_ReleasePolicyEditor> createState() => _ReleasePolicyEditorState();
}

class _ReleasePolicyEditorState extends State<_ReleasePolicyEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _app = TextEditingController(
    text: widget.initial?['application_id'] as String? ?? '',
  );
  late final TextEditingController _minimum = TextEditingController(
    text: widget.initial?['minimum_version'] as String? ?? '1.0.0',
  );
  late final TextEditingController _latest = TextEditingController(
    text: widget.initial?['latest_version'] as String? ?? '1.0.0',
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.initial?['download_url'] as String? ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial?['release_notes'] as String? ?? '',
  );
  late String _platform = widget.initial?['platform'] as String? ?? 'android';
  late bool _enabled = widget.initial?['enabled'] == true;
  late bool _maintenance = widget.initial?['maintenance_mode'] == true;

  @override
  void dispose() {
    _app.dispose();
    _minimum.dispose();
    _latest.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _versionValidator(String? value) =>
      FactoryAppVersion.tryParse(value ?? '') == null
          ? 'Use numeric version, e.g. 1.2.3+4'
          : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final min = FactoryAppVersion.tryParse(_minimum.text.trim())!;
    final latest = FactoryAppVersion.tryParse(_latest.text.trim())!;
    if (min.compareTo(latest) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latest version cannot be below minimum.')),
      );
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'application_id': _app.text.trim(),
      'platform': _platform,
      'minimum_version': _minimum.text.trim(),
      'latest_version': _latest.text.trim(),
      'download_url': _url.text.trim(),
      'release_notes': _notes.text.trim(),
      'enabled': _enabled,
      'maintenance_mode': _maintenance,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Mobile release policy'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _app,
                    readOnly: widget.initial != null,
                    decoration: const InputDecoration(
                      labelText: 'Registered package / bundle ID',
                      helperText: 'Must exactly match the installed app identity',
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*){2,}$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid reverse-domain application ID',
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _platform,
                    decoration: const InputDecoration(labelText: 'Platform'),
                    items: const [
                      DropdownMenuItem(value: 'android', child: Text('Android')),
                      DropdownMenuItem(value: 'ios', child: Text('iOS')),
                    ],
                    onChanged: widget.initial == null
                        ? (value) => setState(() => _platform = value ?? _platform)
                        : null,
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextFormField(
                    controller: _minimum,
                    decoration: const InputDecoration(labelText: 'Minimum supported version'),
                    validator: _versionValidator,
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextFormField(
                    controller: _latest,
                    decoration: const InputDecoration(labelText: 'Latest available version'),
                    validator: _versionValidator,
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextFormField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'Official HTTPS update / store URL',
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      if (uri?.scheme != 'https' ||
                          uri?.host.isEmpty != false ||
                          uri!.userInfo.isNotEmpty) {
                        return 'A trusted HTTPS update URL is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Release notes'),
                  ),
                  SwitchListTile(
                    title: const Text('Publish update policy'),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  SwitchListTile(
                    title: const Text('Maintenance mode'),
                    value: _maintenance,
                    onChanged: (value) => setState(() => _maintenance = value),
                  ),
                  const Text(
                    'Publishing a higher minimum version may block older workers. '
                    'Verify app links and distribution before enabling.',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Save policy')),
        ],
      );
}
