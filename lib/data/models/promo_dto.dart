import '../../domain/entities/promo.dart';
import 'dart:convert';

class PromoDto {
  final String id;
  final String washTypeId;
  final String name;
  final String description;
  final int price;
  final int discountPercent;
  final int duration;
  final int weekendOnly;
  final String includedExtraIds;

  PromoDto({
    required this.id,
    required this.washTypeId,
    required this.name,
    required this.description,
    required this.price,
    required this.discountPercent,
    required this.duration,
    required this.weekendOnly,
    required this.includedExtraIds,
  });

  factory PromoDto.fromMap(Map<String, dynamic> m) => PromoDto(
    id: m['id']?.toString() ?? '',
    washTypeId: m['washTypeId']?.toString() ?? '',
    name: m['name'] ?? '',
    description: m['description'] ?? '',
    price: (m['price'] as num?)?.toInt() ?? 0,
    discountPercent: (m['discountPercent'] as num?)?.toInt() ?? 0,
    duration: (m['duration'] as num?)?.toInt() ?? 0,
    weekendOnly: (m['weekendOnly'] == true || m['weekendOnly'] == 1) ? 1 : 0,
    includedExtraIds: m['includedExtraIds'] is List 
        ? jsonEncode(m['includedExtraIds']) 
        : (m['includedExtraIds'] ?? '[]'),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'washTypeId': washTypeId,
    'name': name,
    'description': description,
    'price': price,
    'discountPercent': discountPercent,
    'duration': duration,
    'weekendOnly': weekendOnly,
    'includedExtraIds': jsonDecode(includedExtraIds),
  };

  Promo toEntity() => Promo(
    id: id,
    washTypeId: washTypeId,
    name: name,
    description: description,
    price: price,
    discountPercent: discountPercent,
    duration: duration,
    weekendOnly: weekendOnly == 1,
    includedExtraIds: _parseJsonList(includedExtraIds),
  );

  static List<String> _parseJsonList(String v) {
    if (v.isEmpty) return [];
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }
}
