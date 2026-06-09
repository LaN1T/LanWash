class ConsumableForecastItem {
  final String consumableId;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double avgDailyUsage;
  final double plannedUsage7d;
  final double? daysUntilLow;
  final double? daysUntilEmpty;
  final double recommendedOrderAmount;
  final String status;

  const ConsumableForecastItem({
    required this.consumableId,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.avgDailyUsage,
    required this.plannedUsage7d,
    this.daysUntilLow,
    this.daysUntilEmpty,
    required this.recommendedOrderAmount,
    required this.status,
  });

  factory ConsumableForecastItem.fromMap(Map<String, dynamic> m) {
    return ConsumableForecastItem(
      consumableId: m['consumable_id'] as String,
      name: m['name'] as String,
      unit: m['unit'] as String,
      currentStock: (m['current_stock'] as num).toDouble(),
      minStock: (m['min_stock'] as num).toDouble(),
      avgDailyUsage: (m['avg_daily_usage'] as num).toDouble(),
      plannedUsage7d: (m['planned_usage_7d'] as num).toDouble(),
      daysUntilLow: m['days_until_low'] != null
          ? (m['days_until_low'] as num).toDouble()
          : null,
      daysUntilEmpty: m['days_until_empty'] != null
          ? (m['days_until_empty'] as num).toDouble()
          : null,
      recommendedOrderAmount:
          (m['recommended_order_amount'] as num).toDouble(),
      status: m['status'] as String,
    );
  }

  bool get isCritical => status == 'critical';
  bool get isWarning => status == 'warning';
  bool get isOk => status == 'ok';
}

class InventoryForecastResponse {
  final List<ConsumableForecastItem> items;
  final String generatedAt;

  const InventoryForecastResponse({
    required this.items,
    required this.generatedAt,
  });

  factory InventoryForecastResponse.fromMap(Map<String, dynamic> m) {
    return InventoryForecastResponse(
      items: (m['items'] as List<dynamic>)
          .map((e) =>
              ConsumableForecastItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      generatedAt: m['generated_at'] as String,
    );
  }

  List<ConsumableForecastItem> get criticalItems =>
      items.where((i) => i.isCritical).toList();

  List<ConsumableForecastItem> get warningItems =>
      items.where((i) => i.isWarning).toList();
}
