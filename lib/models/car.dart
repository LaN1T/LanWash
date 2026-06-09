class Car {
  final int id;
  final String brand;
  final String model;
  final String number;
  final bool isPrimary;

  const Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.number,
    required this.isPrimary,
  });

  String get displayName => '$brand $model'.trim();
  String get fullDisplay => number.isNotEmpty ? '$displayName · $number' : displayName;

  Map<String, dynamic> toMap() => {
        'id': id,
        'brand': brand,
        'model': model,
        'number': number,
        'isPrimary': isPrimary,
      };

  factory Car.fromMap(Map<String, dynamic> m) => Car(
        id: m['id'] as int,
        brand: m['brand'] ?? '',
        model: m['model'] ?? '',
        number: m['number'] ?? '',
        isPrimary: m['isPrimary'] == true || m['isPrimary'] == 1,
      );

  Car copyWith({
    int? id,
    String? brand,
    String? model,
    String? number,
    bool? isPrimary,
  }) =>
      Car(
        id: id ?? this.id,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        number: number ?? this.number,
        isPrimary: isPrimary ?? this.isPrimary,
      );
}
