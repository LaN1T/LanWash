class Note {
  final int? id;
  final String username;
  final String title;
  final String message;
  final String category;
  final bool isRead;
  final DateTime createdAt;

  const Note({
    this.id,
    required this.username,
    required this.title,
    this.message = '',
    this.category = 'general',
    this.isRead = false,
    required this.createdAt,
  });

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'] as int?,
    username: m['username'] ?? '',
    title: m['title'] ?? '',
    message: m['message'] ?? '',
    category: m['category'] ?? 'general',
    isRead: m['isRead'] == true || m['isRead'] == 1,
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'])
        : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'title': title,
    'message': message,
    'category': category,
    'isRead': isRead ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  static const categories = {
    'general': 'Общее',
    'supply': 'Расходники',
    'equipment': 'Оборудование',
    'urgent': 'Срочное',
  };

  String get categoryLabel => categories[category] ?? category;
}
