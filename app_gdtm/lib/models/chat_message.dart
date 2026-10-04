// lib/models/chat_message.dart
import 'package:app_gdtm/models/announcement_item.dart';

/// Một tin nhắn trong khung chat với trợ lý thông báo.
class ChatMessage {
  final bool isUser;
  final String text;

  /// Thông báo liên quan (hiện thành thẻ dưới câu trả lời của bot)
  final List<AnnouncementItem> cards;

  final bool isError;
  final bool isWelcome;

  const ChatMessage({
    required this.isUser,
    required this.text,
    this.cards = const [],
    this.isError = false,
    this.isWelcome = false,
  });
}