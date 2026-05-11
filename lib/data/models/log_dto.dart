import '../../domain/entities/log_entry.dart';

class LogEntryDto {
  final int? id;
  final String username;
  final String action;
  final String details;
  final String timestamp;

  LogEntryDto({
    this.id,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory LogEntryDto.fromMap(Map<String, dynamic> m) => LogEntryDto(
    id: m['id'] as int?,
    username: m['username'] ?? '',
    action: m['action'] ?? '',
    details: m['details'] ?? '',
    timestamp: m['timestamp'] ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'action': action,
    'details': details,
    'timestamp': timestamp,
  };

  LogEntry toEntity() => LogEntry(
    id: id,
    username: username,
    action: action,
    details: details,
    timestamp: DateTime.parse(timestamp),
  );
}
