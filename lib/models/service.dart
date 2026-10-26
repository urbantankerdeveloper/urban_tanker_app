class TankerService {
  const TankerService({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.capacityOptions = const [],
    this.detailOptions = const [],
    this.waterTypeOptions = const [],
    this.tankerCountOptions = const [],
    this.accent,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> capacityOptions;
  final List<String> detailOptions;
  final List<String> waterTypeOptions;
  final List<String> tankerCountOptions;
  final String? accent;

  factory TankerService.fromJson(Map<String, dynamic> json) {
    final config = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    List<String> options(String key) {
      final value = config[key];
      if (value is! List) return const [];
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    return TankerService(
      id: (json['id'] ?? json['code'] ?? '').toString(),
      name: (json['name'] ?? 'Water tanker').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'water').toString(),
      capacityOptions: options('capacityOptions'),
      detailOptions: options('detailOptions'),
      waterTypeOptions: options('waterTypeOptions'),
      tankerCountOptions: options('tankerCountOptions').where((value) {
        final count = int.tryParse(value);
        return count != null && count >= 1 && count <= 5;
      }).toList(growable: false),
      accent: json['accent']?.toString(),
    );
  }
}
