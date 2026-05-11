import 'dart:convert';
import '../domain/entities/appointment.dart';

class AppointmentDto {
  final String id;
  final String clientName;
  final String carModel;
  final String carNumber;
  final String dateTime;
  final String washTypeId;
  final String additionalServices;
  final String status;
  final String notes;
  final int isFavorite;
  final String ownerUsername;
  final int promoPrice;
  final int paidPrice;
  final int originalPrice;
  final int isModifiedByAdmin;
  final int isModifiedByWasher;
  final int isSeenByClient;
  final String assignedWashers;
  final String? promoId;
  final int boxIndex;

  AppointmentDto({
    required this.id,
    required this.clientName,
    required this.carModel,
    required this.carNumber,
    required this.dateTime,
    required this.washTypeId,
    required this.additionalServices,
    required this.status,
    required this.notes,
    required this.isFavorite,
    required this.ownerUsername,
    required this.promoPrice,
    required this.paidPrice,
    required this.originalPrice,
    required this.isModifiedByAdmin,
    required this.isModifiedByWasher,
    required this.isSeenByClient,
    required this.assignedWashers,
    this.promoId,
    required this.boxIndex,
  });

  factory AppointmentDto.fromMap(Map<String, dynamic> m) => AppointmentDto(
    id: m['id']?.toString() ?? '',
    clientName: m['clientName'] ?? '',
    carModel: m['carModel'] ?? '',
    carNumber: m['carNumber'] ?? '',
    dateTime: m['dateTime'] ?? '',
    washTypeId: m['washTypeId']?.toString() ?? '',
    additionalServices: m['additionalServices'] ?? '[]',
    status: m['status'] ?? 'scheduled',
    notes: m['notes'] ?? '',
    isFavorite: (m['isFavorite'] == 1 || m['isFavorite'] == true) ? 1 : 0,
    ownerUsername: m['ownerUsername'] ?? '',
    promoPrice: (m['promoPrice'] as num?)?.toInt() ?? 0,
    paidPrice: (m['paidPrice'] as num?)?.toInt() ?? 0,
    originalPrice: (m['originalPrice'] as num?)?.toInt() ?? 0,
    isModifiedByAdmin: (m['isModifiedByAdmin'] == 1 || m['isModifiedByAdmin'] == true) ? 1 : 0,
    isModifiedByWasher: (m['isModifiedByWasher'] == 1 || m['isModifiedByWasher'] == true) ? 1 : 0,
    isSeenByClient: (m['isSeenByClient'] == 1 || m['isSeenByClient'] == true) ? 1 : 0,
    assignedWashers: m['assignedWasher'] ?? '[]',
    promoId: m['promoId']?.toString(),
    boxIndex: (m['box_index'] as num?)?.toInt() ?? 0,
  );

  Appointment toEntity() => Appointment(
    id: id,
    clientName: clientName,
    carModel: carModel,
    carNumber: carNumber,
    dateTime: DateTime.parse(dateTime),
    washTypeId: washTypeId,
    additionalServices: _parseJsonList(additionalServices),
    status: status,
    notes: notes,
    isFavorite: isFavorite == 1,
    ownerUsername: ownerUsername,
    promoPrice: promoPrice,
    paidPrice: paidPrice,
    originalPrice: originalPrice,
    isModifiedByAdmin: isModifiedByAdmin == 1,
    isModifiedByWasher: isModifiedByWasher == 1,
    isSeenByClient: isSeenByClient == 1,
    assignedWashers: _parseJsonList(assignedWashers),
    promoId: promoId,
    boxIndex: boxIndex,
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
