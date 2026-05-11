import 'service.dart';
import 'wash_type.dart';

class Appointment {
  final String id;
  final String clientName;
  final String carModel;
  final String carNumber;
  final DateTime dateTime;
  final String washTypeId;
  final List<String> additionalServices;
  final String status;
  final String notes;
  final bool isFavorite;
  final String ownerUsername;
  final int promoPrice;
  final int paidPrice;
  final int originalPrice;
  final bool isModifiedByAdmin;
  final bool isModifiedByWasher;
  final bool isSeenByClient;
  final List<String> assignedWashers;
  final String? promoId;
  final int boxIndex;

  Appointment({
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
  Appointment copyWith({
    String? id,
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
    int? boxIndex,
  }) {
    return Appointment(
      id: id ?? this.id,
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
      assignedWashers: assignedWashers ?? this.assignedWashers,
      promoId: promoId ?? this.promoId,
      boxIndex: boxIndex ?? this.boxIndex,
    );
  }
}
