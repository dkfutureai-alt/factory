import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationRulesPage extends StatelessWidget {
  const NotificationRulesPage({super.key, required this.repository});
  final NotificationRepository repository;

  String _priority(FactoryNotificationPriority value) => switch (value) {
        FactoryNotificationPriority.normal => 'Normal',
        FactoryNotificationPriority.high => 'High',
        FactoryNotificationPriority.critical => 'Critical',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alert Rules & Templates', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<List<NotificationRule>>(
          future: repository.loadRules(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load notification rules.'));
            final rules = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Role-scoped operational triggers', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Preview rule registry. Live event dispatch and FCM sending remain backend work.', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: rules.map((rule) => Column(children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(rule.triggerKey, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${rule.audience} • ${rule.channels.map((item) => item.name).join(' + ')}'),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_priority(rule.priority), style: TextStyle(fontWeight: FontWeight.w800, color: rule.priority == FactoryNotificationPriority.critical ? AppTheme.danger : rule.priority == FactoryNotificationPriority.high ? AppTheme.warning : AppTheme.brand)),
                          Text(rule.enabled ? 'Enabled' : 'Disabled', style: const TextStyle(fontSize: 11, color: AppTheme.success)),
                        ]),
                      ),
                      const Divider(height: 1),
                    ])).toList(),
                  ),
                ),
                ),
                const SizedBox(height: 18),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Template preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 12),
                      Text('Maintenance breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text('{{asset_code}} stopped at {{factory_name}}. Open work order {{work_order_number}} for action.', style: TextStyle(color: AppTheme.muted)),
                      SizedBox(height: 12),
                      Text('Push bodies must not include private employee fields or secrets.', style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
