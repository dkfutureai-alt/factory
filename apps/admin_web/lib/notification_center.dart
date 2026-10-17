import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationAdminSnapshot {
  const NotificationAdminSnapshot({
    required this.summary,
    required this.rules,
    required this.templates,
    required this.recent,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> recent;
}

class NotificationAdminRepository {
  NotificationAdminRepository(this.client);
  final SupabaseClient client;

  Future<NotificationAdminSnapshot> load({
    required String organizationId,
    required String? factoryId,
  }) async {
    final summaryRaw = await client.rpc(
      'notification_admin_summary',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
      },
    );
    final ruleRows = await client
        .from('notification_rules')
        .select(
          'id,factory_id,event_key,audience_roles,channels,priority_override,is_active,notification_templates(id,name,category,title_template,body_template,default_priority)',
        )
        .eq('organization_id', organizationId)
        .order('event_key');
    final templateRows = await client
        .from('notification_templates')
        .select(
          'id,template_key,name,category,title_template,body_template,default_priority,is_active',
        )
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final recentRaw = await client.rpc(
      'notification_admin_recent',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_limit': 40,
      },
    );

    final rules = List<Map<String, dynamic>>.from(ruleRows)
        .where(
          (row) => factoryId == null ||
              row['factory_id'] == null ||
              row['factory_id'] == factoryId,
        )
        .toList();
    return NotificationAdminSnapshot(
      summary: Map<String, dynamic>.from(summaryRaw as Map),
      rules: rules,
      templates: List<Map<String, dynamic>>.from(templateRows),
      recent: List<Map<String, dynamic>>.from(recentRaw as List),
    );
  }

  Future<void> setRuleActive(String ruleId, bool active) => client
      .from('notification_rules')
      .update({'is_active': active})
      .eq('id', ruleId);

  Future<void> createRule({
    required String organizationId,
    required String? factoryId,
    required String eventKey,
    required String templateId,
    required List<String> audienceRoles,
    required List<String> channels,
    String? priorityOverride,
  }) => client.from('notification_rules').insert({
        'organization_id': organizationId,
        'factory_id': factoryId,
        'event_key': eventKey,
        'template_id': templateId,
        'audience_roles': audienceRoles,
        'channels': channels,
        'priority_override': priorityOverride,
        'is_active': true,
      });

  Future<int> broadcast({
    required String organizationId,
    required String? factoryId,
    required String title,
    required String body,
    required String priority,
    required List<String> roles,
  }) async {
    final result = await client.rpc(
      'notification_broadcast',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_title': title,
        'p_body': body,
        'p_priority': priority,
        'p_category': 'system',
        'p_roles': roles,
        'p_channels': ['in_app', 'push'],
      },
    );
    return (result as num).toInt();
  }
}

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  late final NotificationAdminRepository repo;
  late String? factoryId;
  late Future<NotificationAdminSnapshot> future;
  bool get canUseOrganizationScope =>
      widget.actorRole == AppRole.platformOwner ||
      widget.actorRole == AppRole.orgAdmin;

  @override
  void initState() {
    super.initState();
    repo = NotificationAdminRepository(Supabase.instance.client);
    factoryId = canUseOrganizationScope || widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
    future = _load();
  }

  Future<NotificationAdminSnapshot> _load() => repo.load(
        organizationId: widget.organizationId,
        factoryId: factoryId,
      );

  void refresh() => setState(() => future = _load());

  String factoryName(String? id) {
    if (id == null) return 'All factories';
    final matches = widget.factories.where((row) => row['id'] == id);
    return matches.isEmpty ? 'Factory' : matches.first['name'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationAdminSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', onRetry: refresh);
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: () async {
            refresh();
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.lg),
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
                onBroadcast: () => _showBroadcast(context),
                onNewRule: () => _showNewRule(context, data),
              ),
              const SizedBox(height: FactorySpacing.lg),
              _SummaryGrid(summary: data.summary),
              const SizedBox(height: FactorySpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;
                  final rules = _RulesPanel(
                    rules: data.rules,
                    actorRole: widget.actorRole,
                    selectedFactoryId: factoryId,
                    factoryName: factoryName,
                    onToggle: _toggleRule,
                  );
                  final recent = _RecentPanel(rows: data.recent);
                  if (!wide) {
                    return Column(
                      children: [
                        rules,
                        const SizedBox(height: FactorySpacing.lg),
                        recent,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: rules),
                      const SizedBox(width: FactorySpacing.lg),
                      Expanded(flex: 4, child: recent),
                    ],
                  );
                },
              ),
              const SizedBox(height: FactorySpacing.lg),
              _TemplatesPanel(rows: data.templates),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleRule(Map<String, dynamic> row, bool value) async {
    try {
      await repo.setRuleActive(row['id'] as String, value);
      refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update rule: $error')),
      );
    }
  }

  Future<void> _showBroadcast(BuildContext context) async {
    if (!canUseOrganizationScope && factoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a factory before broadcasting.')),
      );
      return;
    }
    final title = TextEditingController();
    final body = TextEditingController();
    var priority = 'normal';
    final roles = <String>{'factory_manager', 'supervisor', 'employee', 'driver'};
    final sent = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send notification'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 180,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    ],
                    onChanged: (value) => setDialogState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Audience', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final role in const [
                    ('factory_manager', 'Factory managers'),
                    ('supervisor', 'Supervisors'),
                    ('employee', 'Employees'),
                    ('driver', 'Drivers'),
                  ])
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: roles.contains(role.$1),
                      title: Text(role.$2),
                      onChanged: (checked) => setDialogState(() {
                        if (checked ?? false) {
                          roles.add(role.$1);
                        } else {
                          roles.remove(role.$1);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().length < 2 || body.text.trim().length < 2 || roles.isEmpty) {
                  return;
                }
                try {
                  final count = await repo.broadcast(
                    organizationId: widget.organizationId,
                    factoryId: factoryId,
                    title: title.text.trim(),
                    body: body.text.trim(),
                    priority: priority,
                    roles: roles.toList(),
                  );
                  if (context.mounted) Navigator.pop(context, count);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Broadcast failed: $error')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (sent != null && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Notification created for $sent recipient${sent == 1 ? '' : 's'}.')),
      );
      refresh();
    }
  }

  Future<void> _showNewRule(BuildContext context, NotificationAdminSnapshot data) async {
    if (data.templates.isEmpty) return;
    if (!canUseOrganizationScope && factoryId == null) return;
    String templateId = data.templates.first['id'] as String;
    String eventKey = data.templates.first['template_key'] as String;
    String priority = 'normal';
    final roles = <String>{'factory_manager', 'supervisor'};
    final channels = <String>{'in_app', 'push'};
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create notification rule'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: templateId,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: data.templates
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(row['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final selected = data.templates.firstWhere((row) => row['id'] == value);
                      setDialogState(() {
                        templateId = value;
                        eventKey = selected['template_key'] as String;
                        priority = selected['default_priority'] as String? ?? 'normal';
                      });
                    },
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextFormField(
                    initialValue: eventKey,
                    decoration: const InputDecoration(labelText: 'Event key'),
                    onChanged: (value) => eventKey = value.trim(),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority override'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    ],
                    onChanged: (value) => setDialogState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Audience roles', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Wrap(
                    spacing: FactorySpacing.xs,
                    children: const [
                      ('factory_manager', 'Manager'),
                      ('supervisor', 'Supervisor'),
                      ('employee', 'Employee'),
                      ('driver', 'Driver'),
                    ].map((role) {
                      return FilterChip(
                        label: Text(role.$2),
                        selected: roles.contains(role.$1),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            roles.add(role.$1);
                          } else {
                            roles.remove(role.$1);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Channels', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Wrap(
                    spacing: FactorySpacing.xs,
                    children: const [('in_app', 'In-app'), ('push', 'Push')].map((channel) {
                      return FilterChip(
                        label: Text(channel.$2),
                        selected: channels.contains(channel.$1),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            channels.add(channel.$1);
                          } else {
                            channels.remove(channel.$1);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  if (!canUseOrganizationScope) ...[
                    const SizedBox(height: FactorySpacing.md),
                    const Text('Factory managers can create rules only for their selected factory.'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (eventKey.length < 3 || roles.isEmpty || channels.isEmpty) return;
                try {
                  await repo.createRule(
                    organizationId: widget.organizationId,
                    factoryId: factoryId,
                    eventKey: eventKey,
                    templateId: templateId,
                    audienceRoles: roles.toList(),
                    channels: channels.toList(),
                    priorityOverride: priority,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not create rule: $error')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if ((created ?? false) && mounted) refresh();
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
    required this.onBroadcast,
    required this.onNewRule,
  });

  final String scope;
  final bool canUseOrganizationScope;
  final List<Map<String, dynamic>> factories;
  final String? factoryId;
  final ValueChanged<String?> onFactoryChanged;
  final VoidCallback onRefresh;
  final VoidCallback onBroadcast;
  final VoidCallback onNewRule;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: FactorySpacing.md,
        spacing: FactorySpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Center',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text('$scope · inbox, rules, preferences and delivery health'),
              ],
            ),
          ),
          Wrap(
            spacing: FactorySpacing.sm,
            runSpacing: FactorySpacing.sm,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: factoryId,
                  decoration: const InputDecoration(labelText: 'Factory scope'),
                  items: [
                    if (canUseOrganizationScope)
                      const DropdownMenuItem<String?>(value: null, child: Text('All factories')),
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
              IconButton.filledTonal(onPressed: onRefresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
              OutlinedButton.icon(onPressed: onNewRule, icon: const Icon(Icons.add_alert_outlined), label: const Text('New rule')),
              FilledButton.icon(onPressed: onBroadcast, icon: const Icon(Icons.campaign_outlined), label: const Text('Broadcast')),
            ],
          ),
        ],
      );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('24h notifications', summary['notifications_24h'], Icons.notifications_active_outlined),
      ('Unread', summary['unread'], Icons.mark_email_unread_outlined),
      ('Action required', summary['actionable'], Icons.priority_high),
      ('Push queued', summary['push_queued'], Icons.outbox_outlined),
      ('Push failed', summary['push_failed'], Icons.error_outline),
      ('Active devices', summary['active_devices'], Icons.devices_outlined),
      ('Active rules', summary['active_rules'], Icons.rule_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1250 ? 4 : width >= 760 ? 3 : width >= 480 ? 2 : 1;
        final itemWidth = (width - (columns - 1) * FactorySpacing.sm) / columns;
        return Wrap(
          spacing: FactorySpacing.sm,
          runSpacing: FactorySpacing.sm,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FactorySpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(child: Icon(card.$3)),
                          const SizedBox(width: FactorySpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.$1),
                              Text(
                                '${card.$2 ?? 0}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({
    required this.rules,
    required this.actorRole,
    required this.selectedFactoryId,
    required this.factoryName,
    required this.onToggle,
  });

  final List<Map<String, dynamic>> rules;
  final AppRole actorRole;
  final String? selectedFactoryId;
  final String Function(String?) factoryName;
  final Future<void> Function(Map<String, dynamic>, bool) onToggle;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rules & automation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: FactorySpacing.sm),
              if (rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.lg),
                  child: Text('No notification rules are visible in this scope.'),
                )
              else
                ...rules.map((row) {
                  final template = row['notification_templates'] is Map
                      ? Map<String, dynamic>.from(row['notification_templates'] as Map)
                      : <String, dynamic>{};
                  final channels = List<dynamic>.from(row['channels'] as List? ?? const []);
                  final roles = List<dynamic>.from(row['audience_roles'] as List? ?? const []);
                  final isGlobal = row['factory_id'] == null;
                  final canToggle = actorRole == AppRole.platformOwner ||
                      actorRole == AppRole.orgAdmin ||
                      (!isGlobal && row['factory_id'] == selectedFactoryId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(_categoryIcon(template['category'] as String? ?? 'system')),
                    ),
                    title: Text(template['name'] as String? ?? row['event_key'] as String),
                    subtitle: Wrap(
                      spacing: FactorySpacing.xs,
                      runSpacing: FactorySpacing.xxs,
                      children: [
                        Text(row['event_key'] as String),
                        Text('· ${isGlobal ? 'All factories' : factoryName(row['factory_id'] as String?)}'),
                        if (roles.isNotEmpty) Text('· ${roles.join(', ')}'),
                        ...channels.map((channel) => Chip(label: Text('$channel'), visualDensity: VisualDensity.compact)),
                      ],
                    ),
                    trailing: Switch(
                      value: row['is_active'] as bool? ?? false,
                      onChanged: canToggle ? (value) => onToggle(row, value) : null,
                    ),
                  );
                }),
            ],
          ),
        ),
      );
}

class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent delivery', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: FactorySpacing.sm),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.lg),
                  child: Text('No notification activity yet.'),
                )
              else
                ...rows.take(16).map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          row['push_status'] == 'failed' ? Icons.error_outline : Icons.notifications_outlined,
                          color: row['push_status'] == 'failed' ? FactoryColors.danger : FactoryColors.blue,
                        ),
                        title: Text(row['title'] as String? ?? 'Notification'),
                        subtitle: Text(
                          '${row['recipient_name'] ?? 'Recipient'} · ${row['category'] ?? 'system'} · in-app ${row['in_app_status']} · push ${row['push_status']}',
                        ),
                        trailing: _PriorityBadge(value: row['priority'] as String? ?? 'normal'),
                      ),
                    ),
            ],
          ),
        ),
      );
}

class _TemplatesPanel extends StatelessWidget {
  const _TemplatesPanel({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Templates', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: FactorySpacing.sm),
              Wrap(
                spacing: FactorySpacing.sm,
                runSpacing: FactorySpacing.sm,
                children: rows
                    .map(
                      (row) => Chip(
                        avatar: Icon(_categoryIcon(row['category'] as String? ?? 'system'), size: 18),
                        label: Text('${row['name']} · ${row['default_priority']}'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'critical' => FactoryColors.danger,
      'high' => FactoryColors.warning,
      'low' => Colors.blueGrey,
      _ => FactoryColors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: FactorySpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

IconData _categoryIcon(String category) => switch (category) {
      'inventory' => Icons.inventory_2_outlined,
      'production' => Icons.precision_manufacturing_outlined,
      'quality' => Icons.verified_user_outlined,
      'purchase' || 'sales' => Icons.receipt_long_outlined,
      'warehouse' => Icons.warehouse_outlined,
      'fleet' => Icons.local_shipping_outlined,
      'dispatch' => Icons.route_outlined,
      'maintenance' => Icons.build_circle_outlined,
      'hr' => Icons.groups_2_outlined,
      _ => Icons.notifications_outlined,
    };
