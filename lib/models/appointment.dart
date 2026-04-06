import 'dart:convert';

enum WashType { basic, complex, premium }

extension WashTypeX on WashType {
  String get displayName => switch (this) {
    WashType.basic   => 'Базовая мойка',
    WashType.complex => 'Комплексная мойка',
    WashType.premium => 'Премиум мойка',
  };

  String get description => switch (this) {
    WashType.basic   => 'Активная пена, тщательная ручная очистка и финальное ополаскивание с сушкой',
    WashType.complex => 'Базовая мойка + уборка салона, пылесос, чистка стёкол',
    WashType.premium => 'Комплексная мойка + уход за пластиком, резиной и ароматизация',
  };

  /// Услуги, автоматически включённые в тип мойки (не влияют на цену)
  List<String> get includedExtras => switch (this) {
    WashType.basic   => [],
    WashType.complex => ['Пылесосная уборка'],
    WashType.premium => ['Чернение шин', 'Ароматизация'],
  };

  int get durationMinutes => switch (this) {
    WashType.basic   => 30,
    WashType.complex => 60,
    WashType.premium => 90,
  };

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m мин';
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }

  int get basePrice => switch (this) {
    WashType.basic   => 800,
    WashType.complex => 1500,
    WashType.premium => 3000,
  };

  static WashType fromString(String v) =>
      WashType.values.firstWhere((e) => e.name == v, orElse: () => WashType.basic);
}

class Appointment {
  final String id;
  String clientName;
  String carModel;
  String carNumber;
  DateTime dateTime;
  WashType washType;
  List<String> additionalServices;
  String status;
  String notes;
  bool isFavorite;
  String ownerUsername;
  int promoPrice;
  int paidPrice;     // Актуальная цена (обновляется при изменении админом)
  int originalPrice; // Цена при создании (никогда не меняется)
  bool isModifiedByAdmin; // Флаг: запись изменена админом, клиент ещё не видел

  Appointment({
    required this.id,
    required this.clientName,
    required this.carModel,
    required this.carNumber,
    required this.dateTime,
    required this.washType,
    required this.additionalServices,
    required this.status,
    this.notes = '',
    this.isFavorite = false,
    this.ownerUsername = '',
    this.promoPrice = 0,
    this.paidPrice = 0,
    this.originalPrice = 0,
    this.isModifiedByAdmin = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientName': clientName,
    'carModel': carModel,
    'carNumber': carNumber,
    'dateTime': dateTime.toIso8601String(),
    'washType': washType.name,
    'additionalServices': jsonEncode(additionalServices),
    'status': status,
    'notes': notes,
    'isFavorite': isFavorite ? 1 : 0,
    'ownerUsername': ownerUsername,
    'promoPrice': promoPrice,
    'paidPrice': paidPrice,
    'originalPrice': originalPrice,
    'isModifiedByAdmin': isModifiedByAdmin ? 1 : 0,
  };

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
    id: m['id'],
    clientName: m['clientName'],
    carModel: m['carModel'],
    carNumber: m['carNumber'],
    dateTime: DateTime.parse(m['dateTime']),
    washType: WashTypeX.fromString(m['washType']),
    additionalServices: List<String>.from(jsonDecode(m['additionalServices'])),
    status: m['status'],
    notes: m['notes'] ?? '',
    isFavorite: m['isFavorite'] == 1,
    ownerUsername: m['ownerUsername'] ?? '',
    promoPrice: (m['promoPrice'] as num?)?.toInt() ?? 0,
    paidPrice: (m['paidPrice'] as num?)?.toInt() ?? 0,
    originalPrice: (m['originalPrice'] as num?)?.toInt() ?? 0,
    isModifiedByAdmin: m['isModifiedByAdmin'] == 1 || m['isModifiedByAdmin'] == true,
  );

  Appointment copyWith({
    String? clientName, String? carModel, String? carNumber,
    DateTime? dateTime, WashType? washType, List<String>? additionalServices,
    String? status, String? notes, bool? isFavorite,
    String? ownerUsername, int? promoPrice, int? paidPrice, int? originalPrice,
    bool? isModifiedByAdmin,
  }) => Appointment(
    id: id,
    clientName: clientName ?? this.clientName,
    carModel: carModel ?? this.carModel,
    carNumber: carNumber ?? this.carNumber,
    dateTime: dateTime ?? this.dateTime,
    washType: washType ?? this.washType,
    additionalServices: additionalServices ?? this.additionalServices,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    isFavorite: isFavorite ?? this.isFavorite,
    ownerUsername: ownerUsername ?? this.ownerUsername,
    promoPrice: promoPrice ?? this.promoPrice,
    paidPrice: paidPrice ?? this.paidPrice,
    originalPrice: originalPrice ?? this.originalPrice,
    isModifiedByAdmin: isModifiedByAdmin ?? this.isModifiedByAdmin,
  );

  /// true если админ изменил цену относительно изначальной
  bool get priceChanged => originalPrice > 0 && paidPrice != originalPrice;

  /// Итоговая цена — если сохранена, возвращаем её, иначе вычисляем
  int get totalPrice {
    if (paidPrice > 0) return paidPrice;
    if (promoPrice > 0) return promoPrice;
    const extraPrices = {
      'Чернение шин': 300,
      'Ароматизация': 300,
      'Пылесосная уборка': 500,
      'Полировка стёкол': 500,
      'Антидождь': 600,
      'Обработка арок': 600,
      'Удаление битума': 700,
      'Озонирование': 1000,
      'Нанесение воска': 1200,
      'Мойка двигателя': 1500,
      'Нанесение силанта': 2000,
      'Нанесение тефлона': 3000,
      'Химчистка салона': 3500,
      'Химчистка кожи': 5000,
      'Детейлинг кузова': 8000,
      'Керамическое покрытие': 15000,
    };
    final included = washType.includedExtras;
    int p = washType.basePrice;
    for (final e in additionalServices) {
      if (!included.contains(e)) p += extraPrices[e] ?? 0;
    }
    return p;
  }
}