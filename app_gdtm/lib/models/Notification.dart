import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  String? id;
  String? content;
  String? notificationType;
  String? title;
  bool? isRead;
  DateTime? createAt;
  String? requestId;
  String? userId;
  String? departmentId;

  Notification({
    this.id,
    this.content,
    this.notificationType,
    this.title,
    this.isRead,
    this.createAt,
    this.requestId,
    this.userId,
    this.departmentId,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      content: json['content'],
      notificationType: json['notificationType'],
      title: json['title'],
      isRead: json['isRead'],
      requestId: json['requestId'],
      userId: json['userId'],
      departmentId: json['departmentId'],

      createAt: json['createAt'] != null
          ? DateTime.tryParse(json['createAt'].toString())
          : null,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'notificationType': notificationType,
      'title': title,
      'isRead': isRead,
      'requestId': requestId,
      'userId': userId,
      'departmentId': departmentId,
      'createAt': createAt?.toIso8601String(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Notification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Notification(
      id: doc.id,
      content: data['content'],
      notificationType: data['notificationType'],
      title: data['title'],
      isRead: data['isRead'],
      requestId: data['requestId'],
      userId: data['userId'],
      departmentId: data['departmentId'],
      createAt: (data['createAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
      'notificationType': notificationType,
      'title': title,
      'isRead': isRead,
      'requestId': requestId,
      'userId': userId,
      'departmentId': departmentId,

      'createAt': createAt != null
          ? Timestamp.fromDate(createAt!)
          : null,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Notification copyWith({
    String? id,
    String? content,
    String? notificationType,
    String? title,
    bool? isRead,
    DateTime? createAt,
    String? requestId,
    String? userId,
    String? departmentId,
  }) {
    return Notification(
      id: id ?? this.id,
      content: content ?? this.content,
      notificationType:
          notificationType ?? this.notificationType,
      title: title ?? this.title,
      isRead: isRead ?? this.isRead,
      createAt: createAt ?? this.createAt,
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      departmentId: departmentId ?? this.departmentId,
    );
  }
}