import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecuritySnapshot {
  const SecuritySnapshot({
    required this.summary,
    required this.auditRows,
    required this.accessRows,
    required this.integrity,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> auditRows;
  final List<Map<String, dynamic>> accessRows;
  final Map<String, dynamic> integrity;
}

class SecurityRepository {
  SecurityRepository(this.client);
  final SupabaseClient client;

  Future<SecuritySnapshot> load({
    required String organizationId,
    required String? factoryId,
  }) async {
    final summary = await client.rpc(
      'security_admin_summary',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
      },
    );
    final audit = await client.rpc(
      'security_audit_feed',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_limit': 120,
      },
    );
    final access = await client.rpc(
      'security_access_review',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
      },
    );
    final integrity = await client.rpc(
      'security_verify_audit_integrity',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_limit': 1000,
      },
    );

    return SecuritySnapshot(
      summary: Map<String, dynamic>.from(summary as Map),
      auditRows: List<Map<String, dynamic>>.from(audit as List),
      accessRows: List<Map<String, dynamic>>.from(access as List),
      integrity: Map<String, dynamic>.from(integrity as Map),
    );
  }
}

class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage>
    with SingleTickerProviderStateMixin {
  late final SecurityRepository repo;
  late final TabController tabs;
  late String? factoryId;
  late Future<SecuritySnapshot> future;

  bool get canUseOrganizationScope =>
      widget.actorRole == AppRole.platformOwner ||
      widget.actorRole == AppRole.orgAdmin;

  @override
  void initState() {
    super.initState();
    repo = SecurityRepository(Supabase.instance.client);
    tabs = TabController(length: 3, vsync: this);
    factoryId = canUseOrganizationScope || widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
    future = _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<SecuritySnapshot> _load() => repo.load(
        organizationId: widget.organizationId,
        factoryId: factoryId,
      );

  void refresh() => setState(() => future = _load());

  String factoryName(String? id) {
    if (id == null) return 'All factories';
    final rows = widget.factories.where((row) => row['id'] == id);
    return rows.isEmpty ? 'Factory' : rows.first['name'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SecuritySnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security_outlined, size: 48),
                  const SizedBox(height: FactorySpacing.md),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: FactorySpacing.md),
                  FilledButton(onPressed: refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final data = snapshot.requireData;
        return Column(
          children: [
            _Header(
              scope: factoryName(factoryId),
              canUseOrganizationScope: canUseOrganizationScope,
              factories: widget.factories,
              factoryId: factoryId,
              onFactoryChanged: (value) {
                setState(() {
                  factoryId = value;
                  future = _load();
                });
              },
              onRefresh: refresh,
            ),
            TabBar(
              controller: tabs,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Audit Explorer'),
                Tab(text: 'Access Review'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabs,
                children: [
                  _Overview(snapshot: data, onRefresh: refresh),
                  _AuditExplorer(rows: data.auditRows),
                  _AccessReview(rows: data.accessRows),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scope,
    required this.canUseOrganizationScope,
    required this.factories,
    required this.factoryId,
    required this.onFactoryChanged,
    required this.onRefresh,
  });

  final String scope;
  final bool canUseOrganizationScope;
  final List<Map<String, dynamic>> factories;
  final String? factoryId;
  final ValueChanged<String?> onFactoryChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FactorySpacing.lg,
        FactorySpacing.lg,
        FactorySpacing.lg,
        FactorySpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit & Security',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Security health, access review and tamper-evident audit history.',
                ),
              ],
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: [
                if (canUseOrganizationScope)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All factories'),
                  ),
                ...factories.map(
                  (row) => DropdownMenuItem<String?>(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                ),
              ],
              onChanged: onFactoryChanged,
            ),
          ),
          const SizedBox(width: FactorySpacing.sm),
          IconButton(
            tooltip: 'Refresh $scope',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.snapshot, required this.onRefresh});
  final SecuritySnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final integrity = snapshot.integrity;
    final findings = snapshot.accessRows
        .where((row) => List<String>.from(row['issues'] ?? const []).isNotEmpty)
        .toList();
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Wrap(
            spacing: FactorySpacing.md,
            runSpacing: FactorySpacing.md,
            children: [
              _MetricCard(
                label: 'Audit events • 24h',
                value: '${summary['audit_events_24h'] ?? 0}',
                icon: Icons.history,
              ),
              _MetricCard(
                label: 'High-risk changes • 7d',
                value: '${summary['high_risk_changes_7d'] ?? 0}',
                icon: Icons.warning_amber_outlined,
              ),
              _MetricCard(
                label: 'Access anomalies',
                value: '${summary['access_anomalies'] ?? 0}',
                icon: Icons.person_search_outlined,
              ),
              _MetricCard(
                label: 'Audit integrity',
                value: '${summary['integrity_status'] ?? 'unknown'}'.toUpperCase(),
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final recent = _Panel(
                title: 'Recent Sensitive Activity',
                child: _AuditList(rows: snapshot.auditRows.take(8).toList()),
              );
              final findingsPanel = _Panel(
                title: 'Security Findings',
                child: findings.isEmpty
                    ? const _GoodState(
                        title: 'No access anomalies found',
                        detail: 'Current member and factory assignments are consistent.',
                      )
                    : Column(
                        children: findings.take(6).map((row) {
                          final issues = List<String>.from(row['issues'] ?? const []);
                          return ListTile(
                            leading: const Icon(Icons.report_problem_outlined),
                            title: Text(row['full_name'] as String? ?? 'User'),
                            subtitle: Text(issues.join(' • ')),
                          );
                        }).toList(),
                      ),
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: recent),
                        const SizedBox(width: FactorySpacing.md),
                        Expanded(child: findingsPanel),
                      ],
                    )
                  : Column(
                      children: [
                        recent,
                        const SizedBox(height: FactorySpacing.md),
                        findingsPanel,
                      ],
                    );
            },
          ),
          const SizedBox(height: FactorySpacing.lg),
          _Panel(
            title: 'Audit Integrity & Controls',
            child: Wrap(
              spacing: FactorySpacing.lg,
              runSpacing: FactorySpacing.sm,
              children: [
                _Check(label: 'Integrity status', value: '${integrity['status'] ?? 'unknown'}'),
                _Check(label: 'Rows checked', value: '${integrity['checked_rows'] ?? 0}'),
                _Check(label: 'Broken hashes', value: '${integrity['broken_hashes'] ?? 0}'),
                _Check(label: 'Broken links', value: '${integrity['broken_chain_links'] ?? 0}'),
                _Check(label: 'Scope', value: '${integrity['scope'] ?? 'organization'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditExplorer extends StatefulWidget {
  const _AuditExplorer({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  State<_AuditExplorer> createState() => _AuditExplorerState();
}

class _AuditExplorerState extends State<_AuditExplorer> {
  String severity = 'all';

  @override
  Widget build(BuildContext context) {
    final rows = severity == 'all'
        ? widget.rows
        : widget.rows.where((row) => row['severity'] == severity).toList();
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Audit Explorer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'high', label: Text('High')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'low', label: Text('Low')),
              ],
              selected: {severity},
              onSelectionChanged: (value) => setState(() => severity = value.first),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.md),
        _Panel(title: 'Events', child: _AuditList(rows: rows)),
      ],
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No audit events in this scope.');
    return Column(
      children: rows.map((row) {
        final severity = row['severity'] as String? ?? 'low';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(
              severity == 'high' || severity == 'critical'
                  ? Icons.warning_amber_outlined
                  : Icons.history,
            ),
          ),
          title: Text(
            '${row['action'] ?? 'change'} • ${row['entity_type'] ?? 'entity'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${row['actor_name'] ?? 'System'} • ${_shortTime(row['created_at'])}\n${row['entity_id'] ?? ''}',
          ),
          isThreeLine: true,
          trailing: Chip(label: Text(severity.toUpperCase())),
        );
      }).toList(),
    );
  }
}

class _AccessReview extends StatelessWidget {
  const _AccessReview({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        const Text(
          'Access Review',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.md),
        _Panel(
          title: 'Members & Factory Scope',
          child: rows.isEmpty
              ? const Text('No members in this scope.')
              : Column(
                  children: rows.map((row) {
                    final issues = List<String>.from(row['issues'] ?? const []);
                    final factories = List<String>.from(row['factory_names'] ?? const []);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        issues.isEmpty ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
                      ),
                      title: Text(
                        row['full_name'] as String? ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${row['role'] ?? 'role'} • ${factories.isEmpty ? 'No factory scope' : factories.join(', ')}${issues.isEmpty ? '' : '\n${issues.join(' • ')}'}',
                      ),
                      isThreeLine: issues.isNotEmpty,
                      trailing: Chip(label: Text(issues.isEmpty ? 'OK' : 'REVIEW')),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: FactorySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: FactorySpacing.md),
              child,
            ],
          ),
        ),
      );
}

class _GoodState extends StatelessWidget {
  const _GoodState({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle_outline),
        title: Text(title),
        subtitle: Text(detail),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.check_circle_outline, size: 18),
        label: Text('$label: $value'),
      );
}

String _shortTime(dynamic value) {
  final text = '$value';
  if (text.length >= 16) return text.substring(0, 16).replaceFirst('T', ' ');
  return text;
}
