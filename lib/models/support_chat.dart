class SupportChat {
  final int id;
  final int userId;
  final String userName;
  final String? userPhone;
  final String status;
  final int? assignedAdminId;
  final String? assignedAdminName;
  final int unreadByUser;
  final int unreadByAdmin;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String createdAt;

  SupportChat({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhone,
    required this.status,
    this.assignedAdminId,
    this.assignedAdminName,
    required this.unreadByUser,
    required this.unreadByAdmin,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
  });

  factory SupportChat.fromMap(Map<String, dynamic> m) => SupportChat(
        id: m['id'] as int,
        userId: m['userId'] as int,
        userName: m['userName'] as String,
        userPhone: m['userPhone'] as String?,
        status: m['status'] as String,
        assignedAdminId: m['assignedAdminId'] as int?,
        assignedAdminName: m['assignedAdminName'] as String?,
        unreadByUser: m['unreadByUser'] as int? ?? 0,
        unreadByAdmin: m['unreadByAdmin'] as int? ?? 0,
        lastMessageAt: m['lastMessageAt'] as String?,
        lastMessagePreview: m['lastMessagePreview'] as String?,
        createdAt: m['createdAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        if (userPhone != null) 'userPhone': userPhone,
        'status': status,
        if (assignedAdminId != null) 'assignedAdminId': assignedAdminId,
        if (assignedAdminName != null) 'assignedAdminName': assignedAdminName,
        'unreadByUser': unreadByUser,
        'unreadByAdmin': unreadByAdmin,
        if (lastMessageAt != null) 'lastMessageAt': lastMessageAt,
        if (lastMessagePreview != null)
          'lastMessagePreview': lastMessagePreview,
        'createdAt': createdAt,
      };

  SupportChat copyWith({
    int? id,
    int? userId,
    String? userName,
    String? userPhone,
    String? status,
    int? assignedAdminId,
    String? assignedAdminName,
    int? unreadByUser,
    int? unreadByAdmin,
    String? lastMessageAt,
    String? lastMessagePreview,
    String? createdAt,
  }) =>
      SupportChat(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userPhone: userPhone ?? this.userPhone,
        status: status ?? this.status,
        assignedAdminId: assignedAdminId ?? this.assignedAdminId,
        assignedAdminName: assignedAdminName ?? this.assignedAdminName,
        unreadByUser: unreadByUser ?? this.unreadByUser,
        unreadByAdmin: unreadByAdmin ?? this.unreadByAdmin,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        createdAt: createdAt ?? this.createdAt,
      );
}
