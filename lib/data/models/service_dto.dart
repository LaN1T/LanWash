import '../domain/entities/service.dart';

class ServiceDto {
  final String id;
  final String name;
  final int price;
  final String category;
  final int isActive;

  ServiceDto({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isActive,
  });

  factory ServiceDto.fromMap(Map<String, dynamic> m) => ServiceDto(
    id: m['id']?.toString() ?? '',
    name: m['name'] ?? '',
    price: (m['price'] as num?)?.toInt() ?? 0,
    category: m['category'] ?? '',
    isActive: (m['isActive'] == 1 || m['isActive'] == true) ? 1 : 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'isActive': isActive,
  };

  Service toEntity() => Service(
    id: id,
    name: name,
    price: price,
    category: category,
    isActive: isActive == 1,
  );
}
