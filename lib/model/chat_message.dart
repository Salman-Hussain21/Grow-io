// models/chat_message.dart
class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isUser;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isUser,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isUser': isUser,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isUser: map['isUser'],
    );
  }
}