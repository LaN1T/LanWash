class CancellationsReport {
  final Map<String, dynamic> summary;
  final List<CancellationReportEntry> items;

  CancellationsReport({required this.summary, required this.items});

  factory CancellationsReport.fromJson(Map<String, dynamic> json) {
    return CancellationsReport(
      summary: json['summary'] ?? {},
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CancellationReportEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CancellationReportEntry {
  final String appointmentId;
  final DateTime date;
  final String clientName;
  final String carModel;
  final String? reason;
  final String cancelledBy;
  final double lostRevenue;

  CancellationReportEntry({
    required this.appointmentId,
    required this.date,
    required this.clientName,
    required this.carModel,
    this.reason,
    required this.cancelledBy,
    required this.lostRevenue,
  });

  factory CancellationReportEntry.fromJson(Map<String, dynamic> json) {
    return CancellationReportEntry(
      appointmentId: json['appointment_id'] as String,
      date: DateTime.parse(json['date'] as String),
      clientName: json['client_name'] as String,
      carModel: json['car_model'] as String,
      reason: json['reason'] as String?,
      cancelledBy: json['cancelled_by'] as String,
      lostRevenue: (json['lost_revenue'] as num).toDouble(),
    );
  }
}
