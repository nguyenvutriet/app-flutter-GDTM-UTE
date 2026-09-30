import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Comment.dart';
import 'package:app_gdtm/models/ReactionType.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/VoteCommentId.dart';

class VoteComment {
  VoteCommentId? id;
  ReactionType? type;
  DateTime? voteAt;

  // ID liên kết với Firestore
  String? commentId;
  String? userId;

  // Relationships - dùng ở Flutter
  Users? user;
  Comment? comment;

  VoteComment({
    this.id,
    this.type,
    this.voteAt,
    this.commentId,
    this.userId,
    this.user,
    this.comment,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory VoteComment.fromJson(Map<String, dynamic> json) {
    return VoteComment(
      id: json['id'] != null
          ? VoteCommentId.fromJson(json['id'])
          : null,

      type: ReactionTypeExtension.fromString(
        json['type'] ?? json['reactionType'],
      ),

      voteAt: json['voteAt'] != null
          ? DateTime.tryParse(json['voteAt'].toString())
          : null,

      commentId: json['commentId'],
      userId: json['userId'],

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,

      comment: json['comment'] != null
          ? Comment.fromJson(json['comment'])
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

      'commentId': commentId,
      'userId': userId,

      'user': user?.toJson(),
      'comment': comment?.toJson(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory VoteComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VoteComment(
      // Chỉ đọc id nếu document có field id
      id: data['id'] != null
          ? VoteCommentId.fromJson(data['id'])
          : null,

      type: ReactionTypeExtension.fromString(
        data['reactionType'],
      ),

      commentId: data['commentId'],

      userId: data['userId'],

      voteAt: (data['voteAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'reactionType': type?.toApiString(),

      'commentId': commentId,

      'userId': userId,

      'voteAt': voteAt != null
          ? Timestamp.fromDate(voteAt!)
          : null,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  VoteComment copyWith({
    VoteCommentId? id,
    ReactionType? type,
    DateTime? voteAt,
    String? commentId,
    String? userId,
    Users? user,
    Comment? comment,
  }) {
    return VoteComment(
      id: id ?? this.id,
      type: type ?? this.type,
      voteAt: voteAt ?? this.voteAt,
      commentId: commentId ?? this.commentId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      comment: comment ?? this.comment,
    );
  }
}