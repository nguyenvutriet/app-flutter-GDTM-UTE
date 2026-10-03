import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Announcement.dart';
import 'package:app_gdtm/models/Request.dart';

class FileAttachment {
  String? id;
  String? filename;
  String? fileUrl;
  String? filestype;
  int? filesize;
  DateTime? createat;

  // ID dùng để liên kết với các document khác trong Firestore
  String? requestId;
  String? announcementId;
  String? publicId;
  String? resourceType;
  String? deleteToken;

  // Relationships - dùng ở phía Flutter
  Request? request;
  Announcement? announcement;

  FileAttachment({
    this.id,
    this.filename,
    this.fileUrl,
    this.filestype,
    this.filesize,
    this.createat,
    this.requestId,
    this.announcementId,
    this.publicId,
    this.resourceType,
    this.deleteToken,
    this.request,
    this.announcement,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'],
      filename: json['filename'] ?? json['fileName'],
      fileUrl: json['fileUrl'],
      filestype: json['filestype'] ?? json['fileType'],
      filesize: json['filesize'] ?? json['fileSize'],

      createat: json['createat'] != null
          ? DateTime.tryParse(json['createat'].toString())
          : json['createAt'] != null
              ? DateTime.tryParse(json['createAt'].toString())
              : null,

      requestId: json['requestId'],
      announcementId: json['announcementId'],
      publicId: json['publicId'],
      resourceType: json['resourceType'],
      deleteToken: json['deleteToken'],

      request: json['request'] != null
          ? Request.fromJson(json['request'])
          : null,

      announcement: json['announcement'] != null
          ? Announcement.fromJson(json['announcement'])
          : null,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'fileUrl': fileUrl,
      'filestype': filestype,
      'filesize': filesize,
      'createat': createat?.toIso8601String(),

      'requestId': requestId,
      'announcementId': announcementId,
      'publicId': publicId,
      'resourceType': resourceType,
      'deleteToken': deleteToken,

      'request': request?.toJson(),
      'announcement': announcement?.toJson(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory FileAttachment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FileAttachment(
      id: data['id'] ?? doc.id,

      filename: data['filename'],

      fileUrl: data['fileUrl'],

      filestype: data['filestype'],

      filesize: data['filesize'],

      createat: (data['createat'] as Timestamp?)?.toDate(),

      requestId: data['requestId'],

      announcementId: data['announcementId'],
      publicId: data['publicId'],
      resourceType: data['resourceType'],
      deleteToken: data['deleteToken'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'filename': filename,
      'fileUrl': fileUrl,
      'filestype': filestype,
      'filesize': filesize,

      'createat': createat != null
          ? Timestamp.fromDate(createat!)
          : null,

      'requestId': requestId,
      'announcementId': announcementId,
      'publicId': publicId,
      'resourceType': resourceType,
      'deleteToken': deleteToken,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  FileAttachment copyWith({
    String? id,
    String? filename,
    String? fileUrl,
    String? filestype,
    int? filesize,
    DateTime? createat,
    String? requestId,
    String? announcementId,
    Request? request,
    Announcement? announcement,
    String? publicId,
    String? resourceType,
    String? deleteToken,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      fileUrl: fileUrl ?? this.fileUrl,
      filestype: filestype ?? this.filestype,
      filesize: filesize ?? this.filesize,
      createat: createat ?? this.createat,
      requestId: requestId ?? this.requestId,
      announcementId: announcementId ?? this.announcementId,
      request: request ?? this.request,
      announcement: announcement ?? this.announcement,
      publicId: publicId ?? this.publicId,
      resourceType: resourceType ?? this.resourceType,
      deleteToken: deleteToken ?? this.deleteToken,
    );
  }
}