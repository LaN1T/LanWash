class Consumable {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;

  const Consumable({
    required this.id,
    required this.name,
    required this.unit,
    this.currentStock = 0.0,
    this.minStock = 0.0,
  });

  factory Consumable.fromMap(Map<String, dynamic> map) {
    return Consumable(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['minStock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isLowStock => currentStock < minStock;
}

class ConsumableRefillLog {
  final int id;
  final double amount;
  final double oldStock;
  final double newStock;
  final String refilledBy;
  final String timestamp;

  const ConsumableRefillLog({
    required this.id,
    required this.amount,
    required this.oldStock,
    required this.newStock,
    required this.refilledBy,
    required this.timestamp,
  });

  factory ConsumableRefillLog.fromMap(Map<String, dynamic> map) {
    return ConsumableRefillLog(
      id: map['id'] as int,
      amount: (map['amount'] as num).toDouble(),
      oldStock: (map['oldStock'] as num).toDouble(),
      newStock: (map['newStock'] as num).toDouble(),
      refilledBy: map['refilledBy'] as String,
      timestamp: map['timestamp'] as String,
    );
  }
}

class ConsumableForecast {
  final double currentStock;
  final double minStock;
  final double targetStock;
  final double avgDailyUsage;
  final double? daysLeft;
  final double suggestedPurchase;
  final String unit;

  const ConsumableForecast({
    required this.currentStock,
    required this.minStock,
    required this.targetStock,
    required this.avgDailyUsage,
    this.daysLeft,
    required this.suggestedPurchase,
    required this.unit,
  });

  factory ConsumableForecast.fromMap(Map<String, dynamic> map) {
    return ConsumableForecast(
      currentStock: (map['currentStock'] as num).toDouble(),
      minStock: (map['minStock'] as num).toDouble(),
      targetStock: (map['targetStock'] as num).toDouble(),
      avgDailyUsage: (map['avgDailyUsage'] as num).toDouble(),
      daysLeft:
          map['daysLeft'] != null ? (map['daysLeft'] as num).toDouble() : null,
      suggestedPurchase: (map['suggestedPurchase'] as num).toDouble(),
      unit: map['unit'] as String,
    );
  }
}
