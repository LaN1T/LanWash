class ForecastSlot {
  final String date;
  final int hour;
  final double predictedLoad;
  final int capacity;
  final double utilizationPct;

  ForecastSlot({
    required this.date,
    required this.hour,
    required this.predictedLoad,
    required this.capacity,
    required this.utilizationPct,
  });

  factory ForecastSlot.fromMap(Map<String, dynamic> m) => ForecastSlot(
        date: m['date'] as String,
        hour: m['hour'] as int,
        predictedLoad: (m['predicted_load'] as num).toDouble(),
        capacity: m['capacity'] as int,
        utilizationPct: (m['utilization_pct'] as num).toDouble(),
      );
}

class ForecastResponse {
  final List<ForecastSlot> items;
  final String generatedAt;

  ForecastResponse({required this.items, required this.generatedAt});

  factory ForecastResponse.fromMap(Map<String, dynamic> m) => ForecastResponse(
        items: (m['items'] as List<dynamic>)
            .map((e) => ForecastSlot.fromMap(e as Map<String, dynamic>))
            .toList(),
        generatedAt: m['generated_at'] as String,
      );
}
