/// Authorization context carried by a FactoryOS push navigation request.
/// The server supplies both IDs from the notification's immutable tenant/user
/// row. A route alone is never sufficient to open a mobile business screen.
class ScopedPushRoute {
  const ScopedPushRoute({
    required this.organizationId,
    required this.recipientUserId,
    required this.actionRoute,
  });

  final String organizationId;
  final String recipientUserId;
  final String actionRoute;

  static ScopedPushRoute? fromData(Map<String, dynamic> data) {
    final organizationId = data['organization_id'] is String
        ? (data['organization_id'] as String).trim()
        : '';
    final recipientUserId = data['recipient_user_id'] is String
        ? (data['recipient_user_id'] as String).trim()
        : '';
    final route = data['action_route'] is String
        ? (data['action_route'] as String).trim()
        : '';
    // Legacy and partially populated notifications are intentionally not
    // navigable. Users can still open the signed-in in-app alert inbox.
    if (organizationId.isEmpty || recipientUserId.isEmpty || route.isEmpty) {
      return null;
    }
    return ScopedPushRoute(
      organizationId: organizationId,
      recipientUserId: recipientUserId,
      actionRoute: route,
    );
  }

  bool matches({
    required String organizationId,
    required String recipientUserId,
  }) =>
      this.organizationId == organizationId &&
      this.recipientUserId == recipientUserId;
}

/// Keeps at most one unopened push until the authorized workspace is attached.
/// Never routes a pending push after sign-out or into a different user/tenant.
class ScopedPushMailbox {
  ScopedPushRoute? _pending;

  void store(ScopedPushRoute route) => _pending = route;

  String? consumeFor({
    required String organizationId,
    required String recipientUserId,
  }) {
    final pending = _pending;
    _pending = null;
    return pending != null &&
            pending.matches(
              organizationId: organizationId,
              recipientUserId: recipientUserId,
            )
        ? pending.actionRoute
        : null;
  }

  void clear() => _pending = null;
}
