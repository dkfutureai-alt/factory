class AppModule {
  const AppModule({
    required this.key,
    required this.name,
    required this.sortOrder,
  });

  final String key;
  final String name;
  final int sortOrder;

  factory AppModule.fromMap(Map<String, dynamic> map) {
    return AppModule(
      key: map['key'] as String,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
