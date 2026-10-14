enum FactoryNotificationPriority { normal, high, critical }

enum NotificationChannel { inApp, push }

class FactoryNotification {
  const FactoryNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.module,
    required this.priority,
    required this.createdAt,
    this.route,
    this.isRead = false,
    this.requiresAction = false,
  });

  final String id;
  final String title;
  final String body;
  final String module;
  final FactoryNotificationPriority priority;
  final DateTime createdAt;
  final String? route;
  final bool isRead;
  final bool requiresAction;

  bool get isCritical => priority == FactoryNotificationPriority.critical;
}

class NotificationPreference {
  const NotificationPreference({
    required this.key,
    required this.label,
    required this.description,
    required this.enabled,
    this.isMandatory = false,
  });

  final String key;
  final String label;
  final String description;
  final bool enabled;
  final bool isMandatory;

  bool get effectiveEnabled => isMandatory || enabled;
}

class NotificationOverview {
  const NotificationOverview({required this.notifications, required this.pushEnabledUsers, required this.totalUsers});

  final List<FactoryNotification> notifications;
  final int pushEnabledUsers;
  final int totalUsers;

  int get unreadCount => notifications.where((item) => !item.isRead).length;
  int get criticalCount => notifications.where((item) => item.isCritical && !item.isRead).length;
  int get actionCount => notifications.where((item) => item.requiresAction && !item.isRead).length;
  double get pushEnabledRate => totalUsers <= 0 ? 0 : (pushEnabledUsers / totalUsers).clamp(0, 1).toDouble();
}

class NotificationRule {
  const NotificationRule({
    required this.triggerKey,
    required this.audience,
    required this.priority,
    required this.channels,
    required this.enabled,
  });

  final String triggerKey;
  final String audience;
  final FactoryNotificationPriority priority;
  final Set<NotificationChannel> channels;
  final bool enabled;

  bool get sendsPush => enabled && channels.contains(NotificationChannel.push);
}
