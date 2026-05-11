class Promo {
  final String id;
  final String washTypeId;
  final String name;
  final String description;
  final int price;              // 0 = использовать basePrice со скидкой
  final int discountPercent;    // 0 = фиксированная цена
  final int duration;           // минуты (справочно — пересчитывается)
  final bool weekendOnly;
  final List<String> includedExtraIds;

  Promo({
    required this.id,
    required this.washTypeId,
    required this.name,
    required this.description,
    required this.price,
    required this.discountPercent,
    required this.duration,
    required this.weekendOnly,
    this.includedExtraIds = const [],
  });

  factory Promo.fromMap(Map<String, dynamic> m) => Promo(
    id: m['id']?.toString() ?? '',
    washTypeId: m['washTypeId']?.toString() ?? '',
    name: m['name'] ?? '',
    description: m['description'] ?? '',
    price: _parseInt(m['price']),
    discountPercent: _parseInt(m['discountPercent']),
    duration: _parseInt(m['duration']),
    weekendOnly: m['weekendOnly'] == true || m['weekendOnly'] == 1,
    includedExtraIds: (m['includedExtraIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}
