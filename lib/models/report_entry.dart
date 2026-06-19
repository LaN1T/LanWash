class MonthlyReport {
  final String date;
  final List<ReportEntry> data;

  MonthlyReport({required this.date, required this.data});

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      date: json['date'] ?? '',
      data: (json['data'] as List).map((e) => ReportEntry.fromJson(e)).toList(),
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
      carModel: json['carModel'],
      avgCheck: (json['avgCheck'] as num).toDouble(),
      visitCount: json['visitCount'] as int,
    );
  }
}

class PopularServicesReport {
  final String date;
  final List<PopularServiceEntry> data;

  PopularServicesReport({required this.date, required this.data});

  factory PopularServicesReport.fromJson(Map<String, dynamic> json) {
    return PopularServicesReport(
      date: json['date'] ?? '',
      data: (json['data'] as List)
          .map((e) => PopularServiceEntry.fromJson(e))
          .toList(),
    );
  }
}

class PopularServiceEntry {
  final String serviceName;
  final int count;

  PopularServiceEntry({required this.serviceName, required this.count});

  factory PopularServiceEntry.fromJson(Map<String, dynamic> json) {
    return PopularServiceEntry(
      serviceName: json['serviceName'],
      count: json['count'],
    );
  }
}

class ConsumablesUsageReport {
  final String date;
  final List<ConsumableUsageEntry> data;

  ConsumablesUsageReport({required this.date, required this.data});

  factory ConsumablesUsageReport.fromJson(Map<String, dynamic> json) {
    return ConsumablesUsageReport(
      date: json['date'] ?? '',
      data: (json['data'] as List)
          .map((e) => ConsumableUsageEntry.fromJson(e))
          .toList(),
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
      consumableName: json['consumableName'],
      unit: json['unit'],
      totalUsed: (json['totalUsed'] as num).toDouble(),
    );
  }
}
