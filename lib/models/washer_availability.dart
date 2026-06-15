class WasherAvailability {
  final int id;
  final int userId;
  final String date;
  final String status; // 'available' | 'unavailable'
  final String updatedAt;

  const WasherAvailability({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    required this.updatedAt,
  });

  factory WasherAvailability.fromMap(Map<String, dynamic> map) {
    return WasherAvailability(
      id: map['id'] as int,
      userId: map['userId'] as int,
      date: map['date'] as String,
      status: map['status'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'date': date,
        'status': status,
        'updatedAt': updatedAt,
      };

  WasherAvailability copyWith({
    int? id,
    int? userId,
    String? date,
    String? status,
    String? updatedAt,
  }) {
    return WasherAvailability(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
