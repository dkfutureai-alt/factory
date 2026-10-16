extension FactoryIterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
