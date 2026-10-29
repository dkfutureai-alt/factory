/// Pure identity guard for asynchronous FactoryOS mobile bootstrap results.
/// An organization-only guard is insufficient on shared handsets: a second
/// signed-in user may belong to the *same* organization but a different role.
class MobileSessionIdentity {
  const MobileSessionIdentity(this.userId);

  final String userId;

  bool matches(String? currentUserId) =>
      userId.isNotEmpty && currentUserId != null && userId == currentUserId;

  void requireCurrent(String? currentUserId) {
    if (!matches(currentUserId)) {
      throw StateError(
        'FactoryOS authentication changed while the workspace was loading. '
        'Reload the current account before opening factory data.',
      );
    }
  }
}
