class Tip {
  final int id;
  final String appointmentId;
  final String washerUsername;
  final int amount;
  final String method;
  final String status;
  final DateTime createdAt;
  final String? sbpUrl;

  const Tip({
    required this.id,
    required this.appointmentId,
    required this.washerUsername,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.sbpUrl,
  });

  factory Tip.fromMap(Map<String, dynamic> m) => Tip(
        id: m['id'] as int,
        appointmentId: m['appointmentId']?.toString() ?? '',
        washerUsername: m['washerUsername']?.toString() ?? '',
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        method: m['method']?.toString() ?? 'sbp',
        status: m['status']?.toString() ?? 'pending',
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        sbpUrl: m['sbpUrl']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'appointmentId': appointmentId,
        'washerUsername': washerUsername,
        'amount': amount,
        'method': method,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'sbpUrl': sbpUrl,
      };

  String get methodLabel {
    switch (method) {
      case 'sbp':
        return 'СБП';
      case 'cash':
        return 'Наличные';
      case 'app':
        return 'Через приложение';
      default:
        return method;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Получено';
      case 'pending':
        return 'Ожидает';
      default:
        return status;
    }
  }
}

class TipStats {
  final int totalTips;
  final int totalAmount;
  final int pendingAmount;

  const TipStats({
    required this.totalTips,
    required this.totalAmount,
    required this.pendingAmount,
  });

  factory TipStats.fromMap(Map<String, dynamic> m) => TipStats(
        totalTips: (m['totalTips'] as num?)?.toInt() ?? 0,
        totalAmount: (m['totalAmount'] as num?)?.toInt() ?? 0,
        pendingAmount: (m['pendingAmount'] as num?)?.toInt() ?? 0,
      );
}
