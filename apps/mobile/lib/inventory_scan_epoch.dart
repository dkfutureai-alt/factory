/// Ignores asynchronous scan results from a prior FactoryOS workspace or
/// from an older lookup in the same workspace.
///
/// Intentionally has no Flutter/Supabase dependency, so the race guarantees
/// can be tested without camera hardware or a live production environment.
class InventoryScanEpoch {
  InventoryScanEpoch(this._organizationId);

  String _organizationId;
  int _revision = 0;

  /// Invalidates all outstanding lookups whenever the active organization
  /// changes. A subsequent return to the old org does not revive old results.
  void selectOrganization(String organizationId) {
    if (organizationId == _organizationId) return;
    _organizationId = organizationId;
    _revision++;
  }

  /// Returns a token identifying the latest lookup for this organization.
  int start(String organizationId) {
    if (organizationId != _organizationId) {
      throw StateError('Scan request is not in the active organization');
    }
    return ++_revision;
  }

  bool accepts(String organizationId, int token) =>
      organizationId == _organizationId && token == _revision;

  /// Invalidate a pending scan when the view is disposed or manually reset.
  void invalidate() => _revision++;
}
