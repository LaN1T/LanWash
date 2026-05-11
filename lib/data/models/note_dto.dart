import '../../domain/entities/note.dart';

class NoteDto {
  final int? id;
  final String username;
  final String title;
  final String message;
  final String category;
  final int isRead;
  final String createdAt;

  NoteDto({
    this.id,
    required this.username,
    required this.title,
    required this.message,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });

  factory NoteDto.fromMap(Map<String, dynamic> m) => NoteDto(
    id: m['id'] as int?,
    username: m['username'] ?? '',
    title: m['title'] ?? '',
    message: m['message'] ?? '',
    category: m['category'] ?? 'general',
    isRead: (m['isRead'] == true || m['isRead'] == 1) ? 1 : 0,
    createdAt: m['createdAt'] ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'title': title,
    'message': message,
    'category': category,
    'isRead': isRead,
    'createdAt': createdAt,
  };

  Note toEntity() => Note(
    id: id,
    username: username,
    title: title,
    message: message,
    category: category,
    isRead: isRead == 1,
    createdAt: DateTime.parse(createdAt),
  );
}
