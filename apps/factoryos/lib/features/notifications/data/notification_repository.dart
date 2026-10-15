import '../domain/notification_models.dart';

abstract class NotificationRepository {
  Future<NotificationOverview> loadOverview();
  Future<List<FactoryNotification>> loadInbox({required String audience});
  Future<List<NotificationPreference>> loadPreferences();
  Future<List<NotificationRule>> loadRules();
}

class PreviewNotificationRepository implements NotificationRepository {
  const PreviewNotificationRepository();

  static final List<FactoryNotification> _items = [
    FactoryNotification(
      id: 'NTF-00041',
      title: 'Production line 02 stopped',
      body: 'AC-02 breakdown requires maintenance action.',
      module: 'Maintenance',
      priority: FactoryNotificationPriority.critical,
      createdAt: DateTime(2026, 10, 14, 16, 30),
      route: '/maintenance/work-order',
      requiresAction: true,
    ),
    FactoryNotification(
      id: 'NTF-00040',
      title: 'RM-STL-304-02 below reorder level',
      body: 'Current stock may affect PRD-2026-01040.',
      module: 'Inventory',
      priority: FactoryNotificationPriority.high,
      createdAt: DateTime(2026, 10, 14, 16, 22),
      route: '/inventory/item',
      requiresAction: true,
    ),
    FactoryNotification(
      id: 'NTF-00039',
      title: 'Leave request needs approval',
      body: 'EMP-0018 requested casual leave for 22 Oct 2026.',
      module: 'HR',
      priority: FactoryNotificationPriority.normal,
      createdAt: DateTime(2026, 10, 14, 16, 10),
      route: '/hr/attendance-leave',
      requiresAction: true,
    ),
    FactoryNotification(
      id: 'NTF-00038',
      title: 'Delivery DEL-2026-00681 assigned',
      body: 'Trip TRIP-2026-00814 is ready for pickup.',
      module: 'Delivery',
      priority: FactoryNotificationPriority.normal,
      createdAt: DateTime(2026, 10, 14, 15, 54),
      route: '/delivery/driver',
    ),
    FactoryNotification(
      id: 'NTF-00037',
      title: 'Leave request approved',
      body: 'Your casual leave for 22 Oct 2026 is approved.',
      module: 'HR',
      priority: FactoryNotificationPriority.normal,
      createdAt: DateTime(2026, 10, 13, 17, 5),
      isRead: true,
    ),
  ];

  @override
  Future<NotificationOverview> loadOverview() async => NotificationOverview(
        notifications: _items,
        pushEnabledUsers: 87,
        totalUsers: 100,
      );

  @override
  Future<List<FactoryNotification>> loadInbox({required String audience}) async {
    if (audience == 'driver') {
      return _items.where((item) => item.module == 'Delivery' || item.module == 'Maintenance').toList();
    }
    if (audience == 'employee') {
      return _items.where((item) => item.module == 'HR' || item.module == 'Inventory' || item.module == 'Maintenance').toList();
    }
    return _items;
  }

  @override
  Future<List<NotificationPreference>> loadPreferences() async => const [
        NotificationPreference(key: 'critical', label: 'Critical safety & breakdown', description: 'Mandatory in-app + push', enabled: true, isMandatory: true),
        NotificationPreference(key: 'assigned_work', label: 'Assigned work updates', description: 'Production, trip, delivery and maintenance', enabled: true),
        NotificationPreference(key: 'hr', label: 'HR & leave', description: 'Approvals, holidays and attendance corrections', enabled: true),
        NotificationPreference(key: 'daily_summary', label: 'Daily summary', description: 'One operational summary per day', enabled: false),
      ];

  @override
  Future<List<NotificationRule>> loadRules() async => const [
        NotificationRule(triggerKey: 'inventory.low_stock', audience: 'Warehouse Manager', priority: FactoryNotificationPriority.high, channels: {NotificationChannel.inApp, NotificationChannel.push}, enabled: true),
        NotificationRule(triggerKey: 'maintenance.breakdown', audience: 'Maintenance + Factory Manager', priority: FactoryNotificationPriority.critical, channels: {NotificationChannel.inApp, NotificationChannel.push}, enabled: true),
        NotificationRule(triggerKey: 'leave.approval_required', audience: 'HR Manager', priority: FactoryNotificationPriority.normal, channels: {NotificationChannel.inApp, NotificationChannel.push}, enabled: true),
        NotificationRule(triggerKey: 'delivery.assigned', audience: 'Assigned Driver', priority: FactoryNotificationPriority.normal, channels: {NotificationChannel.inApp, NotificationChannel.push}, enabled: true),
      ];
}
