class PushDeviceRegistration {
  const PushDeviceRegistration({required this.organizationId, required this.platform, required this.token});

  final String organizationId;
  final String platform;
  final String token;

  bool get isValid => organizationId.trim().isNotEmpty && token.trim().length >= 20 && const {'android', 'ios', 'web'}.contains(platform);
}

abstract class NotificationPushPort {
  bool get supportsPush;
  Future<void> registerDevice(PushDeviceRegistration registration);
  Future<void> unregisterDevice(String token);
}

class PreviewNotificationPushPort implements NotificationPushPort {
  const PreviewNotificationPushPort();

  @override
  bool get supportsPush => false;

  @override
  Future<void> registerDevice(PushDeviceRegistration registration) async {
    if (!registration.isValid) throw ArgumentError('Invalid push device registration');
    throw UnsupportedError('FCM transport is not configured in preview mode.');
  }

  @override
  Future<void> unregisterDevice(String token) async {
    if (token.trim().isEmpty) throw ArgumentError('Token is required');
    throw UnsupportedError('FCM transport is not configured in preview mode.');
  }
}
