class WasherPayrollReport {
  final List<WasherPayrollEntry> items;

  WasherPayrollReport({required this.items});

  factory WasherPayrollReport.fromJson(Map<String, dynamic> json) {
    return WasherPayrollReport(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => WasherPayrollEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class WasherPayrollEntry {
  final String washerUsername;
  final String washerName;
  final int appointmentsCount;
  final double servicesTotal;
  final double tipsTotal;
  final double total;

  WasherPayrollEntry({
    required this.washerUsername,
    required this.washerName,
    required this.appointmentsCount,
    required this.servicesTotal,
    required this.tipsTotal,
    required this.total,
  });

  factory WasherPayrollEntry.fromJson(Map<String, dynamic> json) {
    return WasherPayrollEntry(
      washerUsername: json['washer_username'] as String,
      washerName: json['washer_name'] as String,
      appointmentsCount: (json['appointments_count'] as num).toInt(),
      servicesTotal: (json['services_total'] as num).toDouble(),
      tipsTotal: (json['tips_total'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}
