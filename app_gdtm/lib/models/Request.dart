import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/ClarificationConversation.dart';
import 'package:app_gdtm/models/Comment.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/ForwardingLog.dart';
import 'package:app_gdtm/models/RequestStatusHistory.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/Vote.dart';

class Request {
  String? id;
  String? subject;
  String? description;
  String? location;
  String? currentStatus;
  DateTime? timeCreate;
  String? postStatus;

  // ID liên kết với Firestore
  String? departmentId;
  String? userId;

  // Relationships - dùng ở phía Flutter
  List<FileAttachment> fileAttachments;
  List<Category> categories;

  Department? department;
  Users? user;

  List<Comment> comments;

  ClarificationConversation? clarificationConversation;

  List<ForwardingLog> forwardingLogs;

  List<RequestStatusHistory> statusHistory;

  List<Vote> votes;

  Request({
    this.id,
    this.subject,
    this.description,
    this.location,
    this.currentStatus,
    this.timeCreate,
    this.postStatus,
    this.departmentId,
    this.userId,
    this.fileAttachments = const [],
    this.categories = const [],
    this.department,
    this.user,
    this.comments = const [],
    this.clarificationConversation,
    this.forwardingLogs = const [],
    this.statusHistory = const [],
    this.votes = const [],
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'],
      subject: json['subject'],
      description: json['description'],
      location: json['location'],
      currentStatus: json['currentStatus'],
      postStatus: json['postStatus'],

      departmentId: json['departmentId'],
      userId: json['userId'],

      timeCreate: json['timeCreate'] != null
          ? DateTime.tryParse(json['timeCreate'].toString())
          : null,

      fileAttachments: json['fileAttachments'] != null
          ? (json['fileAttachments'] as List)
              .map((e) => FileAttachment.fromJson(e))
              .toList()
          : [],

      categories: json['categories'] != null
          ? (json['categories'] as List)
              .map((e) => Category.fromJson(e))
              .toList()
          : [],

      department: json['department'] != null
          ? Department.fromJson(json['department'])
          : null,

      user: json['user'] != null
          ? Users.fromJson(json['user'])
          : null,

      comments: json['comments'] != null
          ? (json['comments'] as List)
              .map((e) => Comment.fromJson(e))
              .toList()
          : [],

      clarificationConversation:
          json['clarificationConversation'] != null
              ? ClarificationConversation.fromJson(
                  json['clarificationConversation'],
                )
              : null,

      forwardingLogs: json['forwardingLogs'] != null
          ? (json['forwardingLogs'] as List)
              .map((e) => ForwardingLog.fromJson(e))
              .toList()
          : [],

      statusHistory: json['statusHistory'] != null
          ? (json['statusHistory'] as List)
              .map((e) => RequestStatusHistory.fromJson(e))
              .toList()
          : [],

      votes: json['votes'] != null
          ? (json['votes'] as List)
              .map((e) => Vote.fromJson(e))
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
      'subject': subject,
      'description': description,
      'location': location,
      'currentStatus': currentStatus,
      'timeCreate': timeCreate?.toIso8601String(),
      'postStatus': postStatus,

      'departmentId': departmentId,
      'userId': userId,

      'fileAttachments':
          fileAttachments.map((e) => e.toJson()).toList(),

      'categories':
          categories.map((e) => e.toJson()).toList(),

      'department': department?.toJson(),

      'user': user?.toJson(),

      'comments':
          comments.map((e) => e.toJson()).toList(),

      'clarificationConversation':
          clarificationConversation?.toJson(),

      'forwardingLogs':
          forwardingLogs.map((e) => e.toJson()).toList(),

      'statusHistory':
          statusHistory.map((e) => e.toJson()).toList(),

      'votes':
          votes.map((e) => e.toJson()).toList(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Request.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Request(
      id: data['id'] ?? doc.id,

      subject: data['subject'],

      description: data['description'],

      location: data['location'],

      currentStatus: data['currentStatus'],

      postStatus: data['postStatus'],

      departmentId: data['departmentId'],

      userId: data['userId'],

      timeCreate:
          (data['timeCreate'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'subject': subject,
      'description': description,
      'location': location,
      'currentStatus': currentStatus,
      'postStatus': postStatus,

      'departmentId': departmentId,
      'userId': userId,

      'timeCreate': timeCreate != null
          ? Timestamp.fromDate(timeCreate!)
          : null,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Request copyWith({
    String? id,
    String? subject,
    String? description,
    String? location,
    String? currentStatus,
    DateTime? timeCreate,
    String? postStatus,
    String? departmentId,
    String? userId,
    List<FileAttachment>? fileAttachments,
    List<Category>? categories,
    Department? department,
    Users? user,
    List<Comment>? comments,
    ClarificationConversation? clarificationConversation,
    List<ForwardingLog>? forwardingLogs,
    List<RequestStatusHistory>? statusHistory,
    List<Vote>? votes,
  }) {
    return Request(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      location: location ?? this.location,
      currentStatus: currentStatus ?? this.currentStatus,
      timeCreate: timeCreate ?? this.timeCreate,
      postStatus: postStatus ?? this.postStatus,

      departmentId: departmentId ?? this.departmentId,
      userId: userId ?? this.userId,

      fileAttachments:
          fileAttachments ?? this.fileAttachments,

      categories:
          categories ?? this.categories,

      department:
          department ?? this.department,

      user:
          user ?? this.user,

      comments:
          comments ?? this.comments,

      clarificationConversation:
          clarificationConversation ??
              this.clarificationConversation,

      forwardingLogs:
          forwardingLogs ?? this.forwardingLogs,

      statusHistory:
          statusHistory ?? this.statusHistory,

      votes:
          votes ?? this.votes,
    );
  }
}