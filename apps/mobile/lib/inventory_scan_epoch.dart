/// Discard QR/Inventory results after either an organization or authenticated
/// user change. The same organization can have users with different permissions.
///
/// This is a presentation safety boundary; Postgres RLS/RPC authorization
/// remains mandatory for the actual read.
class InventoryScanEpoch {
  InventoryScanEpoch(this._organizationId, this._userId);

  String _organizationId;
  String? _userId;
  int _revision = 0;

  /// Invalidates all pending scans when either tenant or signed-in user changes.
  /// Returning to an earlier account or organization never revives old results.
  bool selectWorkspace(String organizationId, String? userId) {
    if (organizationId == _organizationId && userId == _userId) return false;
    _organizationId = organizationId;
    _userId = userId;
    _revision++;
    return true;
  }

  bool matchesSession(String organizationId, String? userId) =>
      organizationId.isNotEmpty &&
      organizationId == _organizationId &&
      userId != null &&
      userId.isNotEmpty &&
      userId == _userId;

  /// Start a scan only for the exact authenticated user and organization.
  int start(String organizationId, String? userId) {
    if (!matchesSession(organizationId, userId)) {
      throw StateError('Scan request is not in the active authenticated workspace');
    }
    return ++_revision;
  }

  bool accepts(String organizationId, String? userId, int token) =>
      token > 0 &&
      matchesSession(organizationId, userId) &&
      token == _revision;

  /// Invalidate a pending scan when the view is disposed or manually reset.
  void invalidate() => _revision++;
}
