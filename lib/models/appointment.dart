import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'service.dart';
import 'wash_type.dart';

class Appointment {
  final String id;
  String clientName;
  String carModel;
  String carNumber;
  DateTime dateTime;
  String washTypeId; // внешний ключ → wash_types.id
  List<String> additionalServices; // идентификаторы доп. услуг (services.id)
  String status;
  String notes;
  bool isFavorite;
  String ownerUsername;
  int promoPrice;
  int paidPrice;
  int originalPrice;
  bool isModifiedByAdmin;
  bool isModifiedByWasher;
  bool isSeenByClient;
  List<String> assignedWashers;
  String? promoId; // внешний ключ → promos.id
  int box_index;

  Appointment({
    required this.id,
    required this.clientName,
    required this.carModel,
    required this.carNumber,
    required this.dateTime,
    required this.washTypeId,
    required this.additionalServices,
    required this.status,
    this.notes = '',
    this.isFavorite = false,
    this.ownerUsername = '',
    this.promoPrice = 0,
    this.paidPrice = 0,
    this.originalPrice = 0,
    this.isModifiedByAdmin = false,
    this.isModifiedByWasher = false,
    this.isSeenByClient = false,
    List<String>? assignedWashers,
    this.promoId,
    this.box_index = 0,
  }) : assignedWashers = assignedWashers ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientName': clientName,
        'carModel': carModel,
        'carNumber': carNumber,
        'dateTime': dateTime.toIso8601String(),
        'washTypeId': washTypeId,
        'additionalServices': jsonEncode(additionalServices),
        'status': status,
        'notes': notes,
        'isFavorite': isFavorite,
        'ownerUsername': ownerUsername,
        'promoPrice': promoPrice,
        'paidPrice': paidPrice,
        'originalPrice': originalPrice,
        'isModifiedByAdmin': isModifiedByAdmin,
        'isModifiedByWasher': isModifiedByWasher,
        'isSeenByClient': isSeenByClient,
        'assignedWasher': jsonEncode(assignedWashers),
        'promoId': promoId,
        'box_index': box_index,
      };

  factory Appointment.fromMap(Map<String, dynamic> m) {
    try {
      return Appointment(
        id: m['id'] ?? '',
        clientName: m['clientName'] ?? '',
        carModel: m['carModel'] ?? '',
        carNumber: m['carNumber'] ?? '',
        dateTime: _parseDateTime(m['dateTime']),
        washTypeId: m['washTypeId']?.toString() ?? '',
        additionalServices: _parseExtras(m['additionalServices']),
        status: m['status'] ?? 'scheduled',
        notes: m['notes'] ?? '',
        isFavorite: m['isFavorite'] == 1 || m['isFavorite'] == true,
        ownerUsername: m['ownerUsername'] ?? '',
        promoPrice: (m['promoPrice'] as num?)?.toInt() ?? 0,
        paidPrice: (m['paidPrice'] as num?)?.toInt() ?? 0,
        originalPrice: (m['originalPrice'] as num?)?.toInt() ?? 0,
        isModifiedByAdmin:
            m['isModifiedByAdmin'] == 1 || m['isModifiedByAdmin'] == true,
        isModifiedByWasher:
            m['isModifiedByWasher'] == 1 || m['isModifiedByWasher'] == true,
        isSeenByClient: m['isSeenByClient'] == 1 || m['isSeenByClient'] == true,
        assignedWashers: _parseWashers(m['assignedWasher']),
        promoId: m['promoId']?.toString(),
        box_index: (m['box_index'] as num?)?.toInt() ?? 0,
      );
    } catch (e, st) {
      debugPrint('Appointment.fromMap error: $e | map: $m');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null || value == '') {
      return DateTime.now();
    }
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static List<String> _parseExtras(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      if (v.isEmpty) return [];
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static List<String> _parseWashers(dynamic v) {
    if (v == null || v == '') return [];
    if (v is List) return List<String>.from(v);
    if (v is String) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return List<String>.from(decoded);
      } catch (_) {
        if (v.isNotEmpty) return [v];
      }
    }
    return [];
  }

  Appointment copyWith({
    String? clientName,
    String? carModel,
    String? carNumber,
    DateTime? dateTime,
    String? washTypeId,
    List<String>? additionalServices,
    String? status,
    String? notes,
    bool? isFavorite,
    String? ownerUsername,
    int? promoPrice,
    int? paidPrice,
    int? originalPrice,
    bool? isModifiedByAdmin,
    bool? isModifiedByWasher,
    bool? isSeenByClient,
    List<String>? assignedWashers,
    String? promoId,
    int? box_index,
  }) =>
      Appointment(
        id: id,
        clientName: clientName ?? this.clientName,
        carModel: carModel ?? this.carModel,
        carNumber: carNumber ?? this.carNumber,
        dateTime: dateTime ?? this.dateTime,
        washTypeId: washTypeId ?? this.washTypeId,
        additionalServices: additionalServices ?? this.additionalServices,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        isFavorite: isFavorite ?? this.isFavorite,
        ownerUsername: ownerUsername ?? this.ownerUsername,
        promoPrice: promoPrice ?? this.promoPrice,
        paidPrice: paidPrice ?? this.paidPrice,
        originalPrice: originalPrice ?? this.originalPrice,
        isModifiedByAdmin: isModifiedByAdmin ?? this.isModifiedByAdmin,
        isModifiedByWasher: isModifiedByWasher ?? this.isModifiedByWasher,
        isSeenByClient: isSeenByClient ?? this.isSeenByClient,
        assignedWashers: assignedWashers ?? List.from(this.assignedWashers),
        promoId: promoId ?? this.promoId,
        box_index: box_index ?? this.box_index,
      );

  bool get priceChanged => originalPrice > 0 && paidPrice != originalPrice;

  /// Итоговая цена — если сохранена, возвращаем её, иначе считаем
  /// по типу мойки и списку доп.услуг (исключая включённые автоматически).
  int calculateTotalPrice(List<Service> allServices, WashType? washType) {
    if (paidPrice > 0) return paidPrice;

    final base = promoPrice > 0 ? promoPrice : (washType?.basePrice ?? 0);
    final included = washType?.includedExtraIds.toSet() ?? <String>{};

    int p = base;
    for (final id in additionalServices) {
      if (included.contains(id)) continue;
      final svc = _findService(allServices, id);
      if (svc != null) p += svc.price;
    }
    return p;
  }

  static Service? _findService(List<Service> services, String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }
}
