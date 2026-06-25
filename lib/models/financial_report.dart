class FinancialReport {
  final Map<String, num> summary;
  final List<FinancialReportEntry> items;

  FinancialReport({required this.summary, required this.items});

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    return FinancialReport(
      summary: Map<String, num>.from(
        ((json['summary'] ?? {}) as Map<dynamic, dynamic>).map(
          (k, v) => MapEntry(k as String, v as num),
        ),
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => FinancialReportEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class FinancialReportEntry {
  final String period;
  final int appointmentsCount;
  final double servicesTotal;
  final double discountsTotal;
  final double revenue;

  FinancialReportEntry({
    required this.period,
    required this.appointmentsCount,
    required this.servicesTotal,
    required this.discountsTotal,
    required this.revenue,
  });

  factory FinancialReportEntry.fromJson(Map<String, dynamic> json) {
    return FinancialReportEntry(
      period: json['period'] as String,
      appointmentsCount: (json['appointments_count'] as num).toInt(),
      servicesTotal: (json['services_total'] as num).toDouble(),
      discountsTotal: (json['discounts_total'] as num).toDouble(),
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}
