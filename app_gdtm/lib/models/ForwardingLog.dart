import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';

class ForwardingLog {
  String? id;
  String? message;
  String? note;
  DateTime? forwarddAt;

  // ID liên kết với các document khác trong Firestore
  String? fromDepartmentId;
  String? toDepartmentId;
  String? requestId;
  String? userId;

  // Relationships - dùng ở phía Flutter
  Department? fromDepartment;
  Department? toDepartment;
  Request? request;
  Users? user;

  ForwardingLog({
    this.id,
    this.message,
    this.note,
    this.forwarddAt,
    this.fromDepartmentId,
    this.toDepartmentId,
    this.requestId,
    this.userId,
    this.fromDepartment,
    this.toDepartment,
    this.request,
    this.user,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory ForwardingLog.fromJson(Map<String, dynamic> json) {
    return ForwardingLog(
      id: json['id'],
      message: json['message'],
      note: json['note'],

      forwarddAt: json['forwarddAt'] != null
          ? DateTime.tryParse(json['forwarddAt'].toString())
          : json['forwardAt'] != null
              ? DateTime.tryParse(json['forwardAt'].toString())
              : null,

      fromDepartmentId: json['fromDepartmentId'],
      toDepartmentId: json['toDepartmentId'],
      requestId: json['requestId'],
      userId: json['userId'],

      fromDepartment: json['fromDepartment'] != null
          ? Department.fromJson(json['fromDepartment'])
          : json['fromdepartment'] != null
              ? Department.fromJson(json['fromdepartment'])
              : null,

      toDepartment: json['toDepartment'] != null
          ? Department.fromJson(json['toDepartment'])
          : json['todepartment'] != null
              ? Department.fromJson(json['todepartment'])
              : null,

      request: json['request'] != null
          ? Request.fromJson(json['request'])
          : null,

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'note': note,
      'forwarddAt': forwarddAt?.toIso8601String(),

      'fromDepartmentId': fromDepartmentId,
      'toDepartmentId': toDepartmentId,
      'requestId': requestId,
      'userId': userId,

      'fromDepartment': fromDepartment?.toJson(),
      'toDepartment': toDepartment?.toJson(),
      'request': request?.toJson(),
      'user': user?.toJson(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory ForwardingLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ForwardingLog(
      id: data['id'] ?? doc.id,

      message: data['message'],

      note: data['note'],

      forwarddAt: (data['forwarddAt'] as Timestamp?)?.toDate(),

      fromDepartmentId: data['fromDepartmentId'],

      toDepartmentId: data['toDepartmentId'],

      requestId: data['requestId'],

      userId: data['userId'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'message': message,
      'note': note,

      'forwarddAt': forwarddAt != null
          ? Timestamp.fromDate(forwarddAt!)
          : null,

      'fromDepartmentId': fromDepartmentId,
      'toDepartmentId': toDepartmentId,
      'requestId': requestId,
      'userId': userId,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ForwardingLog copyWith({
    String? id,
    String? message,
    String? note,
    DateTime? forwarddAt,
    String? fromDepartmentId,
    String? toDepartmentId,
    String? requestId,
    String? userId,
    Department? fromDepartment,
    Department? toDepartment,
    Request? request,
    Users? user,
  }) {
    return ForwardingLog(
      id: id ?? this.id,
      message: message ?? this.message,
      note: note ?? this.note,
      forwarddAt: forwarddAt ?? this.forwarddAt,

      fromDepartmentId:
          fromDepartmentId ?? this.fromDepartmentId,

      toDepartmentId:
          toDepartmentId ?? this.toDepartmentId,

      requestId: requestId ?? this.requestId,

      userId: userId ?? this.userId,

      fromDepartment:
          fromDepartment ?? this.fromDepartment,

      toDepartment:
          toDepartment ?? this.toDepartment,

      request: request ?? this.request,

      user: user ?? this.user,
    );
  }
}