import 'package:cloud_firestore/cloud_firestore.dart';

import 'comment.dart';
import 'users.dart';

class CommentReport {
  String? id;
  String? reason;
  String status;

  // ID được lưu trực tiếp trên Firestore
  String? adminId;
  String? commentId;
  String? studentId;

  // Relationships - có thể giữ nếu code Flutter cần
  Comment? comment;
  Users? student;
  Users? admin;

  DateTime? createdAt;

  CommentReport({
    this.id,
    this.reason,
    this.status = 'pending',
    this.adminId,
    this.commentId,
    this.studentId,
    this.comment,
    this.student,
    this.admin,
    this.createdAt,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory CommentReport.fromJson(Map<String, dynamic> json) {
    return CommentReport(
      id: json['id'],
      reason: json['reason'],
      status: json['status'] ?? 'pending',

      adminId: json['adminId'],
      commentId: json['commentId'],
      studentId: json['studentId'],

      comment: json['comment'] != null
          ? Comment.fromJson(json['comment'])
          : null,

      student: json['student'] != null
          ? Users.fromJson(json['student'])
          : null,

      admin: json['admin'] != null
          ? Users.fromJson(json['admin'])
          : null,

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reason': reason,
      'status': status,

      'adminId': adminId,
      'commentId': commentId,
      'studentId': studentId,

      'comment': comment?.toJson(),
      'student': student?.toJson(),
      'admin': admin?.toJson(),

      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // ============================================================
  // FIRESTORE MAPPING
  // Collection: commentReport
  // ============================================================

  factory CommentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CommentReport(
      id: data['id'] ?? doc.id,
      reason: data['reason'],
      status: data['status'] ?? '',

      adminId: data['adminId'],
      commentId: data['commentId'],
      studentId: data['studentId'],

      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reason': reason,
      'status': status,

      'adminId': adminId,
      'commentId': commentId,
      'studentId': studentId,

      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : null,
    };
  }
}