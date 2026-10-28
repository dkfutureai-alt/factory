/// Prevent an ambiguous multi-organization mobile session from silently
/// showing or mutating the first organization's data.
///
/// The existing module APIs are not yet uniformly bound to a selected
/// organization, so a selector must not be exposed before all modules migrate.
Map<String, dynamic> requireSingleActiveMembership(
  List<Map<String, dynamic>> activeMemberships,
) {
  if (activeMemberships.isEmpty) {
    throw StateError('No active FactoryOS organization membership.');
  }
  if (activeMemberships.length != 1) {
    throw StateError(
      'This account belongs to multiple active organizations. '
      'The mobile application cannot safely switch between them yet. '
      'Please use the Admin portal or ask your FactoryOS administrator '
      'to provide a dedicated organization-specific test account.',
    );
  }
  return activeMemberships.single;
}
