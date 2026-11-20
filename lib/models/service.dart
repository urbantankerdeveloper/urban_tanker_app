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
    this.minQuantity,
    this.maxQuantity,
    this.unit,
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
  final double? minQuantity;
  final double? maxQuantity;
  final String? unit;
  final String? accent;

  factory TankerService.fromJson(Map<String, dynamic> json) {
    final serviceType = json['service_type'] is Map
        ? Map<String, dynamic>.from(json['service_type'] as Map)
        : const <String, dynamic>{};
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

    double? quantity(Object? value) => value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value)
            : null;

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
      minQuantity: quantity(json['min_quantity'] ??
          json['minQuantity'] ??
          serviceType['min_quantity']),
      maxQuantity: quantity(json['max_quantity'] ??
          json['maxQuantity'] ??
          serviceType['max_quantity']),
      unit: (json['unit'] ?? config['unit'] ?? serviceType['unit'])?.toString(),
      accent: json['accent']?.toString(),
    );
  }
}
