import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, required this.repository, required this.audience});
  final NotificationRepository repository;
  final String audience;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  bool markedAllRead = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [IconButton(onPressed: () => Navigator.of(context).pushNamed('/notifications/preferences'), icon: const Icon(Icons.tune_outlined))],
        ),
        body: FutureBuilder<List<FactoryNotification>>(
          future: widget.repository.loadInbox(audience: widget.audience),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load inbox.'));
            final items = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.audience == 'driver' ? 'Assigned driver alerts' : 'Your factory alerts', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Critical safety alerts remain visible even during quiet hours.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                const SizedBox(height: 14),
                ...items.map((item) => _InboxCard(item: item, forceRead: markedAllRead)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => markedAllRead = true),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark all as read'),
                ),
              ],
            );
          },
        ),
      );
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item, required this.forceRead});
  final FactoryNotification item;
  final bool forceRead;

  Color get accent => switch (item.priority) {
        FactoryNotificationPriority.critical => AppTheme.danger,
        FactoryNotificationPriority.high => AppTheme.warning,
        FactoryNotificationPriority.normal => AppTheme.brand,
      };

  @override
  Widget build(BuildContext context) {
    final read = forceRead || item.isRead;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.route == null ? null : () => Navigator.of(context).pushNamed(item.route!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: read ? AppTheme.border : accent, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w800)),
              const SizedBox(height: 5),
              Text(item.body, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 8),
              Text(item.module, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
      ),
    );
  }
}
