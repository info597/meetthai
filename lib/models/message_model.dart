// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isMine;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });
}
