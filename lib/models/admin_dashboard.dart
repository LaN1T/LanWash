class AdminDashboard {
  final String fromDate;
  final String toDate;
  final int totalRevenue;
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double averageCheck;
  final int newClients;
  final int returningClients;
  final double averageRating;
  final List<DailyBreakdown> dailyBreakdown;
  final List<TopWasher> topWashers;
  final List<TopClient> topClients;

  const AdminDashboard({
    required this.fromDate,
    required this.toDate,
    required this.totalRevenue,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.averageCheck,
    required this.newClients,
    required this.returningClients,
    required this.averageRating,
    required this.dailyBreakdown,
    required this.topWashers,
    required this.topClients,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
        fromDate: json['fromDate'] ?? '',
        toDate: json['toDate'] ?? '',
        totalRevenue: json['totalRevenue'] ?? 0,
        totalAppointments: json['totalAppointments'] ?? 0,
        completedAppointments: json['completedAppointments'] ?? 0,
        cancelledAppointments: json['cancelledAppointments'] ?? 0,
        averageCheck: (json['averageCheck'] as num? ?? 0).toDouble(),
        newClients: json['newClients'] ?? 0,
        returningClients: json['returningClients'] ?? 0,
        averageRating: (json['averageRating'] as num? ?? 0).toDouble(),
        dailyBreakdown: (json['dailyBreakdown'] as List<dynamic>?)
                ?.map((e) => DailyBreakdown.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        topWashers: (json['topWashers'] as List<dynamic>?)
                ?.map((e) => TopWasher.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        topClients: (json['topClients'] as List<dynamic>?)
                ?.map((e) => TopClient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class DailyBreakdown {
  final String date;
  final int revenue;
  final int appointments;
  final int completed;

  const DailyBreakdown({
    required this.date,
    required this.revenue,
    required this.appointments,
    required this.completed,
  });

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) => DailyBreakdown(
        date: json['date'] ?? '',
        revenue: json['revenue'] ?? 0,
        appointments: json['appointments'] ?? 0,
        completed: json['completed'] ?? 0,
      );
}

class TopWasher {
  final String name;
  final int revenue;
  final int appointments;

  const TopWasher({
    required this.name,
    required this.revenue,
    required this.appointments,
  });

  factory TopWasher.fromJson(Map<String, dynamic> json) => TopWasher(
        name: json['name'] ?? '',
        revenue: json['revenue'] ?? 0,
        appointments: json['appointments'] ?? 0,
      );
}

class TopClient {
  final String name;
  final int visits;
  final int totalSpent;

  const TopClient({
    required this.name,
    required this.visits,
    required this.totalSpent,
  });

  factory TopClient.fromJson(Map<String, dynamic> json) => TopClient(
        name: json['name'] ?? '',
        visits: json['visits'] ?? 0,
        totalSpent: json['totalSpent'] ?? 0,
      );
}
