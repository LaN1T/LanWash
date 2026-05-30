class Consumable {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;

  const Consumable({
    required this.id,
    required this.name,
    required this.unit,
    this.currentStock = 0.0,
    this.minStock = 0.0,
  });

  factory Consumable.fromMap(Map<String, dynamic> map) {
    return Consumable(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['minStock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isLowStock => currentStock < minStock;
}
