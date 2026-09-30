import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/Request.dart';

class Category {
  String? id;
  String subject;
  bool isActive;
  List<Request> requests;

  Category({
    this.id,
    required this.subject,
    required this.isActive,
    List<Request>? requests,
  }) : requests = requests ?? [];

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String?,
      subject: json['subject'] as String? ?? '',
      isActive: json['isActive'] as bool? ??
          json['isactive'] as bool? ??
          false,
      requests: json['requests'] != null
          ? (json['requests'] as List)
              .map((item) => Request.fromJson(item))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'isActive': isActive,
      'requests': requests.map((request) => request.toJson()).toList(),
    };
  }

  // ============================================================
  // FIRESTORE MAPPING
  // Collection: categories
  // Fields: id, isActive, subject
  // ============================================================

  /// Tạo Category từ Firestore DocumentSnapshot
  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: data['id'] ?? doc.id,
      subject: data['subject'] ?? '',
      isActive: data['isActive'] ?? false,
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'subject': subject,
      'isActive': isActive,
    };
  }

  Category copyWith({
    String? id,
    String? subject,
    bool? isActive,
    List<Request>? requests,
  }) {
    return Category(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      isActive: isActive ?? this.isActive,
      requests: requests ?? this.requests,
    );
  }
}