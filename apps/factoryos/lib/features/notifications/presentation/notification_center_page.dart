import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key, required this.repository});
  final NotificationRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notification Center', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            TextButton.icon(onPressed: () => Navigator.of(context).pushNamed('/notifications/rules'), icon: const Icon(Icons.rule_outlined), label: const Text('Alert rules')),
          ],
        ),
        body: FutureBuilder<NotificationOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load notifications.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Operational alerts & approvals', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('In-app notification foundation • FCM delivery adapter pending dedicated backend', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 20),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  _Kpi(label: 'Unread', value: '${data.unreadCount}', accent: AppTheme.brand),
                  _Kpi(label: 'Critical', value: '${data.criticalCount}', accent: AppTheme.danger),
                  _Kpi(label: 'Action required', value: '${data.actionCount}', accent: AppTheme.warning),
                  _Kpi(label: 'Push enabled', value: '${(data.pushEnabledRate * 100).toStringAsFixed(0)}%', accent: AppTheme.success),
                ]),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Live inbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ...data.notifications.map((item) => _NotificationRow(item: item)),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: accent)),
            ]),
          ),
        ),
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});
  final FactoryNotification item;

  Color get accent => switch (item.priority) {
        FactoryNotificationPriority.critical => AppTheme.danger,
        FactoryNotificationPriority.high => AppTheme.warning,
        FactoryNotificationPriority.normal => AppTheme.brand,
      };

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 8, backgroundColor: accent),
          title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800)),
          subtitle: Text('${item.module} • ${item.body}'),
          trailing: item.requiresAction ? const Icon(Icons.chevron_right) : null,
          onTap: item.route == null ? null : () => Navigator.of(context).pushNamed(item.route!),
        ),
        const Divider(height: 1),
      ]);
}
