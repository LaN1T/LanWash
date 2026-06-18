class Service {
  final String id;
  String name;
  String description;
  int price;
  int durationMinutes;
  String category;
  bool isFavorite;
  bool isFromApi;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    this.isFavorite = false,
    this.isFromApi = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'durationMinutes': durationMinutes,
        'category': category,
        'isFavorite': isFavorite,
        'isFromApi': isFromApi,
      };

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        id: m['id']?.toString() ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        price: _parseInt(m['price']),
        durationMinutes: _parseInt(m['durationMinutes']),
        category: m['category'] ?? '',
        isFavorite: m['isFavorite'] == 1 || m['isFavorite'] == true,
        isFromApi: m['isFromApi'] == 1 || m['isFromApi'] == true,
      );

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  Service copyWith({
    String? name,
    String? description,
    int? price,
    int? durationMinutes,
    String? category,
    bool? isFavorite,
  }) =>
      Service(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        category: category ?? this.category,
        isFavorite: isFavorite ?? this.isFavorite,
        isFromApi: isFromApi,
      );

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes мин';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }
}
