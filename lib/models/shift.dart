class Shift {
  final int id;
  final int userId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  const Shift({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'] as int,
      userId: map['userId'] as int,
      date: map['date'] as String,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      status: map['status'] as String,
      createdBy: map['createdBy'] as String,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  int get durationMinutes {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    if (start == null || end == null) return 0;
    var diff = end.difference(start).inMinutes;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  static DateTime? _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(2000, 1, 1, h, m);
  }
}
