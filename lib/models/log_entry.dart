class LogEntry {
  final int? id;
  final String username;
  final String action;
  final String details;
  final DateTime timestamp;

  const LogEntry({
    this.id,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
        id: m['id'] as int?,
        username: m['username'] ?? '',
        action: m['action'] ?? '',
        details: m['details'] ?? '',
        timestamp: DateTime.parse(m['timestamp']),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'action': action,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };
}
