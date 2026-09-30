import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/Message.dart';
import 'package:app_gdtm/models/Request.dart';

class ClarificationConversation {
  String? id;
  bool? isOpen;
  String? subject;
  DateTime? createAt;
  String? requestId;
  Request? request;
  List<Message> messages;

  ClarificationConversation({
    this.id,
    this.isOpen,
    this.subject,
    this.createAt,
    this.requestId,
    this.request,
    List<Message>? messages,
  }) : messages = messages ?? [];

  factory ClarificationConversation.fromJson(Map<String, dynamic> json) {
    return ClarificationConversation(
      id: json['id'] as String?,
      isOpen: json['isOpen'] as bool? ?? json['open'] as bool?,
      subject: json['subject'] as String?,
      createAt: json['createAt'] != null
          ? DateTime.tryParse(json['createAt'].toString())
          : null,
      requestId: json['requestId'],
      request: json['request'] != null
          ? Request.fromJson(json['request'] as Map<String, dynamic>)
          : null,
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map(
                (message) =>
                    Message.fromJson(message as Map<String, dynamic>),
              )
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isOpen': isOpen,
      'subject': subject,
      'createAt': createAt?.toIso8601String(),
      'requestId': requestId,
      'request': request?.toJson(),
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  // ============================================================
  // FIRESTORE MAPPING
  // Collection: clarificationconversation
  // Fields: createAt (Timestamp), id, isOpen, requestId, subject
  // ============================================================

  /// Tạo từ Firestore DocumentSnapshot
  factory ClarificationConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClarificationConversation(
      id: data['id'] ?? doc.id,
      isOpen: data['isOpen'],
      subject: data['subject'],
      createAt: (data['createAt'] as Timestamp?)?.toDate(),
      requestId: data['requestId'],
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'isOpen': isOpen,
      'subject': subject,
      'createAt': createAt != null ? Timestamp.fromDate(createAt!) : null,
      'requestId': requestId,
    };
  }
}