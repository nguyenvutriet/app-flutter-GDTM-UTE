import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/ReactionType.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/VoteId.dart';

class Vote {
  VoteId? id;
  ReactionType? type;

  DateTime? voteAt;

  // ID liên kết với Firestore
  String? requestId;
  String? userId;

  // Relationships - dùng ở phía Flutter
  Users? user;
  Request? request;

  Vote({
    this.id,
    this.type,
    this.voteAt,
    this.requestId,
    this.userId,
    this.user,
    this.request,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] != null
          ? VoteId.fromJson(json['id'])
          : null,

      type: ReactionTypeExtension.fromString(
        json['type'] ?? json['reactionType'],
      ),

      voteAt: json['voteAt'] != null
          ? DateTime.tryParse(json['voteAt'].toString())
          : null,

      requestId: json['requestId'],

      userId: json['userId'],

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,

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
      'id': id?.toJson(),

      'type': type?.toApiString(),

      'voteAt': voteAt?.toIso8601String(),

      'requestId': requestId,

      'userId': userId,

      'user': user?.toJson(),

      'request': request?.toJson(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Vote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Vote(
      id: data['id'] != null
          ? VoteId.fromJson(data['id'])
          : null,

      type: ReactionTypeExtension.fromString(
        data['reactionType'],
      ),

      requestId: data['requestId'],

      userId: data['userId'],

      voteAt: (data['voteAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id?.toJson(),

      'reactionType': type?.toApiString(),

      'requestId': requestId,

      'userId': userId,

      'voteAt': voteAt != null
          ? Timestamp.fromDate(voteAt!)
          : null,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Vote copyWith({
    VoteId? id,
    ReactionType? type,
    DateTime? voteAt,
    String? requestId,
    String? userId,
    Users? user,
    Request? request,
  }) {
    return Vote(
      id: id ?? this.id,
      type: type ?? this.type,
      voteAt: voteAt ?? this.voteAt,
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      request: request ?? this.request,
    );
  }
}