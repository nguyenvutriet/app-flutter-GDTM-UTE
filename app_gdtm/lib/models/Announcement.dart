import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Users.dart';

class Announcement {
  String? id;
  String? title;
  String? content;
  DateTime? date;
  String? userId;
  List<FileAttachment> attachments;
  Users? user;

  Announcement({
    this.id,
    this.title,
    this.content,
    this.date,
    this.userId,
    this.attachments = const [],
    this.user,
  });



  // Convert JSON -> Announcement
  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : null,
      userId: json['userId'],

      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((e) => FileAttachment.fromJson(e))
              .toList()
          : [],

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,
    );
  }

  // Convert Announcement -> JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date?.toIso8601String(),
      'userId': userId,

      'attachments':
          attachments.map((e) => e.toJson()).toList(),

      'user': user?.toJson(),
    };
  }

  // ============================================================
  // FIRESTORE MAPPING
  // Collection: announcement
  // Fields: content, date (Timestamp), id, title, userId
  // ============================================================

  /// Tạo Announcement từ Firestore DocumentSnapshot
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: data['id'] ?? doc.id,
      title: data['title'],
      content: data['content'],
      date: (data['date'] as Timestamp?)?.toDate(),
      userId: data['userId'],
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'userId': userId,
    };
  }
}