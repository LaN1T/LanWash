import '../../domain/entities/wash_type.dart';
import 'dart:convert';

class WashTypeDto {
  final String id;
  final String code;
  final String name;
  final String description;
  final int basePrice;
  final int durationMinutes;
  final int sortOrder;
  final String includedExtraIds;

  WashTypeDto({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.durationMinutes,
    required this.sortOrder,
    required this.includedExtraIds,
  });

  factory WashTypeDto.fromMap(Map<String, dynamic> m) => WashTypeDto(
    id: m['id']?.toString() ?? '',
    code: m['code']?.toString() ?? '',
    name: m['name'] ?? '',
    description: m['description'] ?? '',
    basePrice: (m['basePrice'] as num?)?.toInt() ?? 0,
    durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 0,
    sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
    includedExtraIds: m['includedExtraIds'] is List 
        ? jsonEncode(m['includedExtraIds']) 
        : (m['includedExtraIds'] ?? '[]'),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'basePrice': basePrice,
    'durationMinutes': durationMinutes,
    'sortOrder': sortOrder,
    'includedExtraIds': jsonDecode(includedExtraIds),
  };

  WashType toEntity() => WashType(
    id: id,
    code: code,
    name: name,
    description: description,
    basePrice: basePrice,
    durationMinutes: durationMinutes,
    sortOrder: sortOrder,
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
