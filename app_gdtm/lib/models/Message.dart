import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  String? id;
  String? content;
  DateTime? createAt;
  String? clarificationConversationId;
  String? senderId;
  String? receiverId;

  Message({
    this.id,
    this.content,
    this.createAt,
    this.clarificationConversationId,
    this.senderId,
    this.receiverId,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],

      createAt: json['createAt'] != null
          ? DateTime.tryParse(json['createAt'].toString())
          : null,

      clarificationConversationId:
          json['clarificationConversationId'],

      senderId: json['senderId'],

      receiverId: json['receiverId'],
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createAt': createAt?.toIso8601String(),
      'clarificationConversationId':
          clarificationConversationId,
      'senderId': senderId,
      'receiverId': receiverId,
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Message(
      id: data['id'] ?? doc.id,

      content: data['content'],

      createAt: (data['createAt'] as Timestamp?)?.toDate(),

      clarificationConversationId:
          data['clarificationConversationId'],

      senderId: data['senderId'],

      receiverId: data['receiverId'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,

      'createAt': createAt != null
          ? Timestamp.fromDate(createAt!)
          : null,

      'clarificationConversationId':
          clarificationConversationId,

      'senderId': senderId,

      'receiverId': receiverId,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Message copyWith({
    String? id,
    String? content,
    DateTime? createAt,
    String? clarificationConversationId,
    String? senderId,
    String? receiverId,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      createAt: createAt ?? this.createAt,
      clarificationConversationId:
          clarificationConversationId ??
              this.clarificationConversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
    );
  }
}