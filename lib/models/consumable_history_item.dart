class ConsumableHistoryItem {
  final String type; // 'consumption' | 'refill'
  final int id;
  final double quantity;
  final DateTime timestamp;
  final String? appointmentId;

  const ConsumableHistoryItem({
    required this.type,
    required this.id,
    required this.quantity,
    required this.timestamp,
    this.appointmentId,
  });

  factory ConsumableHistoryItem.fromMap(Map<String, dynamic> map) {
    return ConsumableHistoryItem(
      type: map['type'] as String,
      id: map['id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      appointmentId: map['appointmentId'] as String?,
    );
  }

  bool get isConsumption => type == 'consumption';
  bool get isRefill => type == 'refill';
}
