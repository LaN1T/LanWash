class SubscriptionPlan {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String type; // 'package' | 'unlimited'
  final int? washCount;
  final int? unlimitedDays;
  final int discountPercent;
  final Map<String, int>? washTypePrices;
  final int sortOrder;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    this.washCount,
    this.unlimitedDays,
    required this.discountPercent,
    this.washTypePrices,
    required this.sortOrder,
    required this.isActive,
  });

  bool get isPackage => type == 'package';
  bool get isUnlimited => type == 'unlimited';

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) {
    return SubscriptionPlan(
      id: (m['id'] as num).toInt(),
      code: m['code']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString(),
      type: m['type']?.toString() ?? 'package',
      washCount: (m['washCount'] as num?)?.toInt(),
      unlimitedDays: (m['unlimitedDays'] as num?)?.toInt(),
      discountPercent: (m['discountPercent'] as num?)?.toInt() ?? 0,
      washTypePrices: (m['washTypePrices'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toInt())),
      sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: m['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'type': type,
        'washCount': washCount,
        'unlimitedDays': unlimitedDays,
        'discountPercent': discountPercent,
        'washTypePrices': washTypePrices,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };
}
