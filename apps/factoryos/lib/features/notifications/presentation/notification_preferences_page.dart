import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key, required this.repository});
  final NotificationRepository repository;

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final Map<String, bool> overrides = {};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification preferences', style: TextStyle(fontWeight: FontWeight.w800))),
        body: FutureBuilder<List<NotificationPreference>>(
          future: widget.repository.loadPreferences(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load preferences.'));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Choose your alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Critical safety and breakdown alerts cannot be disabled.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                const SizedBox(height: 16),
                ...snapshot.requireData.map((preference) {
                  final enabled = preference.isMandatory ? true : (overrides[preference.key] ?? preference.enabled);
                  return Card(
                    child: SwitchListTile(
                      value: enabled,
                      onChanged: preference.isMandatory ? null : (value) => setState(() => overrides[preference.key] = value),
                      title: Text(preference.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(preference.description),
                      secondary: Icon(preference.isMandatory ? Icons.shield_outlined : Icons.notifications_outlined, color: preference.isMandatory ? AppTheme.danger : AppTheme.brand),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.bedtime_outlined, color: AppTheme.brand),
                    title: Text('Quiet hours', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('10:00 PM – 06:00 AM • Critical alerts bypass quiet hours'),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
