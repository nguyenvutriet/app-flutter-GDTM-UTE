import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Request.dart';

class RequestStatusHistory {
  String? id;
  String? status;
  DateTime? createAt;

  // ID liên kết với Request trong Firestore
  String? requestId;

  // Relationship - dùng ở phía Flutter
  Request? request;

  RequestStatusHistory({
    this.id,
    this.status,
    this.createAt,
    this.requestId,
    this.request,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory RequestStatusHistory.fromJson(Map<String, dynamic> json) {
    return RequestStatusHistory(
      id: json['id'],
      status: json['status'],

      createAt: json['createAt'] != null
          ? DateTime.tryParse(json['createAt'].toString())
          : null,

      requestId: json['requestId'],

      request: json['request'] != null
          ? Request.fromJson(json['request'])
          : null,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'createAt': createAt?.toIso8601String(),

      'requestId': requestId,

      'request': request?.toJson(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory RequestStatusHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RequestStatusHistory(
      id: data['id'] ?? doc.id,

      status: data['status'],

      createAt: (data['createAt'] as Timestamp?)?.toDate(),

      requestId: data['requestId'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'status': status,

      'createAt': createAt != null
          ? Timestamp.fromDate(createAt!)
          : null,

      'requestId': requestId,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  RequestStatusHistory copyWith({
    String? id,
    String? status,
    DateTime? createAt,
    String? requestId,
    Request? request,
  }) {
    return RequestStatusHistory(
      id: id ?? this.id,
      status: status ?? this.status,
      createAt: createAt ?? this.createAt,
      requestId: requestId ?? this.requestId,
      request: request ?? this.request,
    );
  }
}