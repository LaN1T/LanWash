class Subscription {
  final int id;
  final int userId;
  final String name;
  final String type; // 'package' or 'monthly'
  final String washTypeId;
  final int totalWashes;
  final int usedWashes;
  final String? validUntil; // ISO date for monthly; null for package
  final String createdAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.washTypeId,
    required this.totalWashes,
    required this.usedWashes,
    this.validUntil,
    required this.createdAt,
  });

  bool get isActive {
    if (usedWashes >= totalWashes) return false;
    if (validUntil != null) {
      try {
        final expiry = DateTime.parse(validUntil!);
        return expiry.isAfter(DateTime.now());
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  int get remaining => totalWashes - usedWashes;

  double get progress => totalWashes > 0 ? usedWashes / totalWashes : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type,
        'washTypeId': washTypeId,
        'totalWashes': totalWashes,
        'usedWashes': usedWashes,
        'validUntil': validUntil,
        'createdAt': createdAt,
      };

  factory Subscription.fromMap(Map<String, dynamic> m) {
    return Subscription(
      id: (m['id'] as num).toInt(),
      userId: (m['userId'] as num).toInt(),
      name: m['name'] ?? '',
      type: m['type'] ?? 'package',
      washTypeId: m['washTypeId']?.toString() ?? '',
      totalWashes: (m['totalWashes'] as num?)?.toInt() ?? 0,
      usedWashes: (m['usedWashes'] as num?)?.toInt() ?? 0,
      validUntil: m['validUntil']?.toString(),
      createdAt: m['createdAt'] ?? '',
    );
  }
}
