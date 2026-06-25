class MonthlyReport {
  final String date;
  final List<ReportEntry> data;

  MonthlyReport({required this.date, required this.data});

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      date: json['month'] as String? ?? '',
      data: (json['items'] as List<dynamic>?)
              ?.map((e) => ReportEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ReportEntry {
  final String carModel;
  final double avgCheck;
  final int visitCount;

  ReportEntry({
    required this.carModel,
    required this.avgCheck,
    required this.visitCount,
  });

  factory ReportEntry.fromJson(Map<String, dynamic> json) {
    return ReportEntry(
      carModel: json['car_model'] as String? ?? '',
      avgCheck: (json['avg_check'] as num).toDouble(),
      visitCount: (json['visit_count'] as num).toInt(),
    );
  }
}

class PopularServicesReport {
  final String date;
  final List<PopularServiceEntry> data;

  PopularServicesReport({required this.date, required this.data});

  factory PopularServicesReport.fromJson(Map<String, dynamic> json) {
    return PopularServicesReport(
      date: json['month'] as String? ?? '',
      data: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  PopularServiceEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PopularServiceEntry {
  final String serviceName;
  final int count;

  PopularServiceEntry({required this.serviceName, required this.count});

  factory PopularServiceEntry.fromJson(Map<String, dynamic> json) {
    return PopularServiceEntry(
      serviceName: json['name'] as String? ?? '',
      count: (json['count'] as num).toInt(),
    );
  }
}

class ConsumablesUsageReport {
  final String date;
  final List<ConsumableUsageEntry> data;

  ConsumablesUsageReport({required this.date, required this.data});

  factory ConsumablesUsageReport.fromJson(Map<String, dynamic> json) {
    return ConsumablesUsageReport(
      date: json['month'] as String? ?? '',
      data: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  ConsumableUsageEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ConsumableUsageEntry {
  final String consumableName;
  final String unit;
  final double totalUsed;

  ConsumableUsageEntry({
    required this.consumableName,
    required this.unit,
    required this.totalUsed,
  });

  factory ConsumableUsageEntry.fromJson(Map<String, dynamic> json) {
    return ConsumableUsageEntry(
      consumableName: json['consumable_name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      totalUsed: (json['total_used'] as num).toDouble(),
    );
  }
}
