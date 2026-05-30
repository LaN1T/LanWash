class WashType {
  final String id; // w1..w4
  final String code; // код типа мойки: express/basic/complex/premium
  final String name;
  final String description;
  final int basePrice;
  final int durationMinutes;
  final int sortOrder;
  final List<String> includedExtraIds; // id доп.услуг (services.id)

  WashType({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.durationMinutes,
    required this.sortOrder,
    this.includedExtraIds = const [],
  });

  factory WashType.fromMap(Map<String, dynamic> m) => WashType(
        id: m['id']?.toString() ?? '',
        code: m['code']?.toString() ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        basePrice: _parseInt(m['basePrice']),
        durationMinutes: _parseInt(m['durationMinutes']),
        sortOrder: _parseInt(m['sortOrder']),
        includedExtraIds: (m['includedExtraIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'basePrice': basePrice,
        'durationMinutes': durationMinutes,
        'sortOrder': sortOrder,
        'includedExtraIds': includedExtraIds,
      };

  WashType copyWith({
    String? name,
    String? description,
    int? basePrice,
    int? durationMinutes,
    int? sortOrder,
    List<String>? includedExtraIds,
  }) =>
      WashType(
        id: id,
        code: code,
        name: name ?? this.name,
        description: description ?? this.description,
        basePrice: basePrice ?? this.basePrice,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        sortOrder: sortOrder ?? this.sortOrder,
        includedExtraIds: includedExtraIds ?? this.includedExtraIds,
      );

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m мин';
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}
