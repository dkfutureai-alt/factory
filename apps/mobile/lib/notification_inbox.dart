import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationMobileSnapshot {
  const NotificationMobileSnapshot({
    required this.organizationId,
    required this.inbox,
    required this.preferences,
    required this.unread,
  });

  final String organizationId;
  final List<Map<String, dynamic>> inbox;
  final Map<String, dynamic> preferences;
  final int unread;
}

class NotificationMobileRepository {
  NotificationMobileRepository(this.client);
  final SupabaseClient client;

  Future<NotificationMobileSnapshot> load({bool unreadOnly = false}) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id')
        .eq('user_id', client.auth.currentUser!.id)
        .eq('is_active', true)
        .limit(1);
    if (memberships.isEmpty) throw StateError('No active organization membership found.');
    final organizationId = memberships.first['organization_id'] as String;
    final inboxRaw = await client.rpc(
      'notification_inbox',
      params: {'p_limit': 100, 'p_unread_only': unreadOnly},
    );
    final prefsRaw = await client.rpc(
      'notification_my_preferences',
      params: {'p_organization_id': organizationId},
    );
    final unreadRaw = await client.rpc('notification_unread_count');
    return NotificationMobileSnapshot(
      organizationId: organizationId,
      inbox: List<Map<String, dynamic>>.from(inboxRaw as List),
      preferences: Map<String, dynamic>.from(prefsRaw as Map),
      unread: (unreadRaw as num).toInt(),
    );
  }

  Future<void> markRead(String id) async {
    await client.rpc('notification_mark_read', params: {'p_notification_id': id});
  }

  Future<int> markAllRead() async {
    final result = await client.rpc('notification_mark_all_read');
    return (result as num).toInt();
  }

  Future<Map<String, dynamic>> updatePreferences({
    required String organizationId,
    required bool inAppEnabled,
    required bool pushEnabled,
    required bool allowCritical,
    String? quietStart,
    String? quietEnd,
    required List<String> mutedCategories,
  }) async {
    final result = await client.rpc(
      'notification_update_preferences',
      params: {
        'p_organization_id': organizationId,
        'p_in_app_enabled': inAppEnabled,
        'p_push_enabled': pushEnabled,
        'p_quiet_hours_start': quietStart,
        'p_quiet_hours_end': quietEnd,
        'p_allow_critical_during_quiet': allowCritical,
        'p_muted_categories': mutedCategories,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({this.onOpenRoute, super.key});
  final ValueChanged<String>? onOpenRoute;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  late final NotificationMobileRepository repo;
  late Future<NotificationMobileSnapshot> future;
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    repo = NotificationMobileRepository(Supabase.instance.client);
    future = repo.load();
  }

  void refresh() => setState(() => future = repo.load(unreadOnly: unreadOnly));

  @override
  Widget build(BuildContext context) => FutureBuilder<NotificationMobileSnapshot>(
        future: future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Alerts'),
                  if (data != null && data.unread > 0) ...[
                    const SizedBox(width: FactorySpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FactoryColors.danger,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${data.unread}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (data != null)
                  IconButton(
                    tooltip: 'Preferences',
                    onPressed: () => _showPreferences(data),
                    icon: const Icon(Icons.tune),
                  ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: _body(snapshot),
          );
        },
      );

  Widget _body(AsyncSnapshot<NotificationMobileSnapshot> snapshot) {
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
              const Icon(Icons.notifications_off_outlined, size: 48),
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
    return RefreshIndicator(
      onRefresh: () async {
        refresh();
        await future;
      },
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('All'), icon: Icon(Icons.inbox_outlined)),
                    ButtonSegment(value: true, label: Text('Unread'), icon: Icon(Icons.mark_email_unread_outlined)),
                  ],
                  selected: {unreadOnly},
                  onSelectionChanged: (value) {
                    setState(() {
                      unreadOnly = value.first;
                      future = repo.load(unreadOnly: unreadOnly);
                    });
                  },
                ),
              ),
              if (data.unread > 0) ...[
                const SizedBox(width: FactorySpacing.sm),
                TextButton(
                  onPressed: () async {
                    await repo.markAllRead();
                    refresh();
                  },
                  child: const Text('Mark all read'),
                ),
              ],
            ],
          ),
          const SizedBox(height: FactorySpacing.md),
          if (data.inbox.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(FactorySpacing.xl),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 54, color: FactoryColors.blue),
                    SizedBox(height: FactorySpacing.md),
                    Text('No alerts in this view.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
          else
            ...data.inbox.map((row) => _notificationCard(row)),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> row) {
    final unread = row['read_at'] == null;
    final priority = row['priority'] as String? ?? 'normal';
    final category = row['category'] as String? ?? 'system';
    final color = _priorityColor(priority);
    return Card(
      margin: const EdgeInsets.only(bottom: FactorySpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(FactoryRadius.lg),
        onTap: () => _openNotification(row),
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .10),
                    child: Icon(_categoryIcon(category), color: color),
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: FactoryColors.blue, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: FactorySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row['title'] as String? ?? 'Notification',
                            style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700),
                          ),
                        ),
                        _PriorityChip(priority: priority),
                      ],
                    ),
                    const SizedBox(height: FactorySpacing.xxs),
                    Text(
                      row['body'] as String? ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: FactorySpacing.xs),
                    Text(
                      '$category · ${_timeAgo(row['created_at'] as String?)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> row) async {
    if (row['read_at'] == null) {
      await repo.markRead(row['notification_id'] as String);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final route = row['action_route'] as String?;
        final metadata = row['metadata'] is Map
            ? Map<String, dynamic>.from(row['metadata'] as Map)
            : <String, dynamic>{};
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, 0, FactorySpacing.lg, FactorySpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PriorityChip(priority: row['priority'] as String? ?? 'normal'),
                const SizedBox(height: FactorySpacing.sm),
                Text(
                  row['title'] as String? ?? 'Notification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: FactorySpacing.sm),
                Text(row['body'] as String? ?? ''),
                const SizedBox(height: FactorySpacing.md),
                Text(
                  '${row['category'] ?? 'system'} · ${_timeAgo(row['created_at'] as String?)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: FactorySpacing.md),
                  Wrap(
                    spacing: FactorySpacing.xs,
                    runSpacing: FactorySpacing.xs,
                    children: metadata.entries
                        .where((entry) => entry.value is String || entry.value is num || entry.value is bool)
                        .take(5)
                        .map((entry) => Chip(label: Text('${entry.key}: ${entry.value}')))
                        .toList(),
                  ),
                ],
                if (route != null && route.isNotEmpty && widget.onOpenRoute != null) ...[
                  const SizedBox(height: FactorySpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onOpenRoute!(route);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open related item'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    refresh();
  }

  Future<void> _showPreferences(NotificationMobileSnapshot data) async {
    var inApp = data.preferences['in_app_enabled'] as bool? ?? true;
    var push = data.preferences['push_enabled'] as bool? ?? true;
    var critical = data.preferences['allow_critical_during_quiet'] as bool? ?? true;
    final muted = List<String>.from(data.preferences['muted_categories'] as List? ?? const []);
    final quietStart = data.preferences['quiet_hours_start'] as String?;
    final quietEnd = data.preferences['quiet_hours_end'] as String?;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification preferences'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In-app notifications'),
                    subtitle: const Text('Show alerts in the FactoryOS inbox'),
                    value: inApp,
                    onChanged: (value) => setDialogState(() => inApp = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push notifications'),
                    subtitle: Text('${data.preferences['active_devices'] ?? 0} active device(s)'),
                    value: push,
                    onChanged: (value) => setDialogState(() => push = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Critical alerts bypass quiet hours'),
                    value: critical,
                    onChanged: (value) => setDialogState(() => critical = value),
                  ),
                  if (quietStart != null && quietEnd != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bedtime_outlined),
                      title: const Text('Quiet hours'),
                      subtitle: Text('$quietStart – $quietEnd'),
                    ),
                  if (muted.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.volume_off_outlined),
                      title: const Text('Muted categories'),
                      subtitle: Text(muted.join(', ')),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await repo.updatePreferences(
                    organizationId: data.organizationId,
                    inAppEnabled: inApp,
                    pushEnabled: push,
                    allowCritical: critical,
                    quietStart: quietStart,
                    quietEnd: quietEnd,
                    mutedCategories: muted,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save preferences: $error')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if ((saved ?? false) && mounted) refresh();
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        priority,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

Color _priorityColor(String priority) => switch (priority) {
      'critical' => FactoryColors.danger,
      'high' => FactoryColors.warning,
      'low' => Colors.blueGrey,
      _ => FactoryColors.blue,
    };

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

String _timeAgo(String? raw) {
  final created = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  if (created == null) return 'recently';
  final delta = DateTime.now().difference(created);
  if (delta.inMinutes < 1) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  return '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';
}
