class SupportMessage {
  final int id;
  final int chatId;
  final String senderRole;
  final int? senderId;
  final String? senderName;
  final String content;
  final bool isAiDraft;
  final String createdAt;

  SupportMessage({
    required this.id,
    required this.chatId,
    required this.senderRole,
    this.senderId,
    this.senderName,
    required this.content,
    required this.isAiDraft,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> m) => SupportMessage(
        id: m['id'] as int,
        chatId: m['chatId'] as int,
        senderRole: m['senderRole'] as String,
        senderId: m['senderId'] as int?,
        senderName: m['senderName'] as String?,
        content: m['content'] as String,
        isAiDraft: m['isAiDraft'] as bool? ?? false,
        createdAt: m['createdAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'senderRole': senderRole,
        if (senderId != null) 'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        'content': content,
        'isAiDraft': isAiDraft,
        'createdAt': createdAt,
      };
}
