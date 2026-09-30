import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/CommentReport.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/VoteComment.dart';

class Comment {
  String? id;
  String? content;
  DateTime? date;
  bool isActive;

  // Reply fields
  String? parentId;
  String? replyId;
  String? replyToUserId;
  String? replyToUsername;

  // Firestore references
  String? requestId;
  String? userId;

  // Relationships - có thể giữ nếu code Flutter cần
  Request? request;
  Users? user;
  Comment? parentComment;
  List<Comment> replies;
  List<CommentReport> commentReports;
  List<VoteComment> voteComments;

  Comment({
    this.id,
    this.content,
    this.date,
    this.isActive = true,
    this.parentId,
    this.replyId,
    this.replyToUserId,
    this.replyToUsername,
    this.requestId,
    this.userId,
    this.request,
    this.user,
    this.parentComment,
    this.replies = const [],
    this.commentReports = const [],
    this.voteComments = const [],
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      isActive: json['isActive'] ?? true,

      parentId: json['parentId'],
      replyId: json['replyId'],
      replyToUserId: json['replyToUserId'],
      replyToUsername: json['replyToUsername'] ?? json['replyToUserName'],

      requestId: json['requestId'],
      userId: json['userId'],

      request: json['request'] != null
          ? Request.fromJson(json['request'])
          : null,

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,

      parentComment: json['parentComment'] != null
          ? Comment.fromJson(json['parentComment'])
          : null,

      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((e) => Comment.fromJson(e))
              .toList()
          : [],

      commentReports: json['commentReports'] != null
          ? (json['commentReports'] as List)
              .map((e) => CommentReport.fromJson(e))
              .toList()
          : [],

      voteComments: json['voteComments'] != null
          ? (json['voteComments'] as List)
              .map((e) => VoteComment.fromJson(e))
              .toList()
          : [],
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'date': date?.toIso8601String(),
      'isActive': isActive,

      'parentId': parentId,
      'replyId': replyId,
      'replyToUserId': replyToUserId,
      'replyToUsername': replyToUsername,

      'requestId': requestId,
      'userId': userId,

      'request': request?.toJson(),
      'user': user?.toJson(),
      'parentComment': parentComment?.toJson(),

      'replies': replies.map((e) => e.toJson()).toList(),

      'commentReports':
          commentReports.map((e) => e.toJson()).toList(),

      'voteComments':
          voteComments.map((e) => e.toJson()).toList(),
    };
  }

  // ============================================================
  // FIRESTORE MAPPING
  // Collection: comments
  // ============================================================

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Comment(
      id: data['id'] ?? doc.id,
      content: data['content'],
      date: (data['date'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,

      parentId: data['parentId'],
      replyId: data['replyId'],
      replyToUserId: data['replyToUserId'],
      replyToUsername: data['replyToUsername'],

      requestId: data['requestId'],
      userId: data['userId'],
    );
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'isActive': isActive,

      'parentId': parentId,
      'replyId': replyId,
      'replyToUserId': replyToUserId,
      'replyToUsername': replyToUsername,

      'requestId': requestId,
      'userId': userId,
    };
  }
}