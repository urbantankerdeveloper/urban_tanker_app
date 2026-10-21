class TankerService {
  const TankerService({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.accent,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String? accent;

  factory TankerService.fromJson(Map<String, dynamic> json) {
    return TankerService(
      id: (json['id'] ?? json['code'] ?? '').toString(),
      name: (json['name'] ?? 'Water tanker').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'water').toString(),
      accent: json['accent']?.toString(),
    );
  }
}
