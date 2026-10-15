import 'package:factoryos/features/notifications/domain/notification_models.dart';
import 'package:factoryos/features/notifications/domain/notification_push_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification overview derives unread critical and action counts', () {
    final overview = NotificationOverview(
      pushEnabledUsers: 87,
      totalUsers: 100,
      notifications: [
        FactoryNotification(id: '1', title: 'Critical', body: 'A', module: 'Maintenance', priority: FactoryNotificationPriority.critical, createdAt: DateTime(2026), requiresAction: true),
        FactoryNotification(id: '2', title: 'High', body: 'B', module: 'Inventory', priority: FactoryNotificationPriority.high, createdAt: DateTime(2026), requiresAction: true),
        FactoryNotification(id: '3', title: 'Read', body: 'C', module: 'HR', priority: FactoryNotificationPriority.normal, createdAt: DateTime(2026), isRead: true),
      ],
    );

    expect(overview.unreadCount, 2);
    expect(overview.criticalCount, 1);
    expect(overview.actionCount, 2);
    expect(overview.pushEnabledRate, closeTo(0.87, 0.0001));
  });

  test('push enabled rate is bounded and zero-safe', () {
    const zero = NotificationOverview(notifications: [], pushEnabledUsers: 5, totalUsers: 0);
    const over = NotificationOverview(notifications: [], pushEnabledUsers: 15, totalUsers: 10);
    expect(zero.pushEnabledRate, 0);
    expect(over.pushEnabledRate, 1);
  });

  test('mandatory preferences cannot be effectively disabled', () {
    const preference = NotificationPreference(key: 'critical', label: 'Critical', description: 'Required', enabled: false, isMandatory: true);
    expect(preference.effectiveEnabled, isTrue);
  });

  test('notification rule only sends push when enabled and channel selected', () {
    const enabled = NotificationRule(triggerKey: 'delivery.assigned', audience: 'Driver', priority: FactoryNotificationPriority.normal, channels: {NotificationChannel.inApp, NotificationChannel.push}, enabled: true);
    const disabled = NotificationRule(triggerKey: 'delivery.assigned', audience: 'Driver', priority: FactoryNotificationPriority.normal, channels: {NotificationChannel.push}, enabled: false);
    expect(enabled.sendsPush, isTrue);
    expect(disabled.sendsPush, isFalse);
  });

  test('push registration validates supported platform and token length', () {
    const valid = PushDeviceRegistration(organizationId: 'org-1', platform: 'android', token: '12345678901234567890');
    const invalid = PushDeviceRegistration(organizationId: 'org-1', platform: 'desktop', token: 'short');
    expect(valid.isValid, isTrue);
    expect(invalid.isValid, isFalse);
    expect(const PreviewNotificationPushPort().supportsPush, isFalse);
  });
}
