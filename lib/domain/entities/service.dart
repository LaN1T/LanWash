class Service {
  final String id;
  final String name;
  final int price;
  final String category;
  final bool isActive;

  Service({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isActive,
  });

  Service copyWith({
    String? id,
    String? name,
    int? price,
    String? category,
    bool? isActive,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }
}
