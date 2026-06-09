class Review {
  final int id;
  final int userId;
  final String userName;
  final int rating;
  final String comment;
  final bool isPublished;
  final DateTime createdAt;
  final String? appointmentId;

  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.isPublished,
    required this.createdAt,
    this.appointmentId,
  });

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        id: m['id'] as int,
        userId: m['userId'] as int,
        userName: m['userName'] ?? '',
        rating: m['rating'] ?? 5,
        comment: m['comment'] ?? '',
        isPublished: m['isPublished'] == true || m['isPublished'] == 1,
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        appointmentId: m['appointmentId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'isPublished': isPublished ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        if (appointmentId != null) 'appointmentId': appointmentId,
      };

  String get statusLabel => isPublished ? 'Опубликован' : 'На модерации';
}
