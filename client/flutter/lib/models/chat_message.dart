class ChatMessage {
  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String content;
  final String type; // "user" | "system"
  final int timestamp;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.content,
    this.type = 'user',
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'user',
      timestamp: json['timestamp'] ?? 0,
    );
  }

  bool get isSystem => type == 'system';
}
