class DailyReport {
  final String date;
  final int revenue;
  final int appointmentsCount;
  final int completedCount;
  final double averageCheck;
  final Map<String, int> boxOccupancy;
  final List<TopService> topServices;
  final List<WasherShift> washersOnShift;
  final List<ConsumableAlert> consumablesAlert;

  const DailyReport({
    required this.date,
    required this.revenue,
    required this.appointmentsCount,
    required this.completedCount,
    required this.averageCheck,
    required this.boxOccupancy,
    required this.topServices,
    required this.washersOnShift,
    required this.consumablesAlert,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) => DailyReport(
        date: json['date'] ?? '',
        revenue: json['revenue'] ?? 0,
        appointmentsCount: json['appointmentsCount'] ?? 0,
        completedCount: json['completedCount'] ?? 0,
        averageCheck: (json['averageCheck'] as num? ?? 0).toDouble(),
        boxOccupancy: (json['boxOccupancy'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int)) ??
            {},
        topServices: (json['topServices'] as List<dynamic>?)
                ?.map((e) => TopService.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        washersOnShift: (json['washersOnShift'] as List<dynamic>?)
                ?.map((e) => WasherShift.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        consumablesAlert: (json['consumablesAlert'] as List<dynamic>?)
                ?.map(
                    (e) => ConsumableAlert.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class TopService {
  final String name;
  final int count;

  const TopService({required this.name, required this.count});

  factory TopService.fromJson(Map<String, dynamic> json) => TopService(
        name: json['name'] ?? '',
        count: json['count'] ?? 0,
      );
}

class WasherShift {
  final String name;
  final String start;
  final String end;

  const WasherShift(
      {required this.name, required this.start, required this.end});

  factory WasherShift.fromJson(Map<String, dynamic> json) => WasherShift(
        name: json['name'] ?? '',
        start: json['start'] ?? '',
        end: json['end'] ?? '',
      );
}

class ConsumableAlert {
  final String name;
  final double currentStock;
  final double minStock;

  const ConsumableAlert({
    required this.name,
    required this.currentStock,
    required this.minStock,
  });

  factory ConsumableAlert.fromJson(Map<String, dynamic> json) =>
      ConsumableAlert(
        name: json['name'] ?? '',
        currentStock: (json['currentStock'] as num? ?? 0).toDouble(),
        minStock: (json['minStock'] as num? ?? 0).toDouble(),
      );
}
