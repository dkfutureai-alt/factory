extension FactoryMapIterableExtensions on Iterable<Map<String, dynamic>> {
  Map<String, dynamic>? get firstOrNull => isEmpty ? null : first;
}
