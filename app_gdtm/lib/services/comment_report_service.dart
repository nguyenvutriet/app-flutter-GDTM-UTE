// lib/services/comment_report_service.dart
// Admin kiểm duyệt báo cáo bình luận (collection: commentreport).
// Phía sinh viên gửi báo cáo nằm trong ForumService.reportComment().
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/services/forum_service.dart';

class ReportStatus {
  static const String pending = 'pending';
  static const String notViolation = 'not_violation';
  static const String violation = 'violation';
}

/// Một dòng báo cáo đã gộp sẵn nội dung bình luận, tên người báo cáo, tên admin...
class ReportItem {
  final String id;
  final String reason;
  final String status;
  final DateTime? createdAt;

  final String commentId;
  final bool commentExists;
  final String commentContent;
  final bool commentActive;
  final String? requestId;

  final String reporterId;
  final String reporterName;

  const ReportItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.commentId,
    required this.reporterId,
    required this.reporterName,
    this.createdAt,
    this.commentExists = true,
    this.commentContent = '',
    this.commentActive = true,
    this.requestId,
  });
}

class CommentReportService {
  static const String reportsCollection = ForumService.commentReportsCollection;
  static const int _whereInLimit = 30;

  final FirebaseFirestore _db;
  final String? Function() _getCurrentUserId;

  /// [currentUserId]: Users.id của admin đang đăng nhập.
  CommentReportService({
    required String? Function() currentUserId,
    FirebaseFirestore? db,
  })  : _getCurrentUserId = currentUserId,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final id = _getCurrentUserId();
    if (id == null || id.isEmpty) throw ForumException('Chưa đăng nhập!');
    return id;
  }

  /// Tất cả báo cáo (mới nhất trước) kèm thông tin bình luận + người dùng.
  Future<List<ReportItem>> getReports() async {
    _uid;
    final snap = await _db.collection(reportsCollection).get();
    if (snap.docs.isEmpty) return [];

    final reports = snap.docs.map((d) => MapEntry(d.id, d.data())).toList();

    final commentIds =
        reports.map((e) => e.value['commentId']).whereType<String>().toSet();
    final userIds =
        reports.map((e) => e.value['studentId']).whereType<String>().toSet();

    final comments = await _loadComments(commentIds);
    final users = await _loadUsers(userIds);

    final items = reports.map((e) {
      final m = e.value;
      final commentId = m['commentId']?.toString() ?? '';
      final c = comments[commentId];
      final studentId = m['studentId']?.toString() ?? '';
      return ReportItem(
        id: e.key,
        reason: m['reason']?.toString() ?? '',
        status: (m['status']?.toString().isNotEmpty ?? false)
            ? m['status'].toString()
            : ReportStatus.pending,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        commentId: commentId,
        commentExists: c != null,
        commentContent: c?['content']?.toString() ?? '[Bình luận không còn tồn tại]',
        commentActive: c == null ? false : c['isActive'] != false,
        requestId: c?['requestId']?.toString(),
        reporterId: studentId,
        reporterName: _userName(users[studentId], fallback: studentId),
      );
    }).toList();

    items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return items;
  }

  /// Admin duyệt báo cáo.
  /// - violation = true: đánh dấu vi phạm + ẩn bình luận (isActive = false).
  ///   Các báo cáo khác còn "đang chờ" của cùng bình luận cũng được chốt là vi phạm.
  /// - violation = false: không vi phạm. Nếu trước đó đã bị ẩn vì vi phạm thì hiện lại.
  Future<void> resolve(ReportItem item, {required bool violation}) async {
    _uid; // bắt buộc đăng nhập
    final status = violation ? ReportStatus.violation : ReportStatus.notViolation;

    final same = await _db
        .collection(reportsCollection)
        .where('commentId', isEqualTo: item.commentId)
        .get();

    final batch = _db.batch();
    for (final d in same.docs) {
      final isThis = d.id == item.id;
      final isPending =
          (d.data()['status']?.toString() ?? ReportStatus.pending) ==
              ReportStatus.pending;
      if (isThis || (violation && isPending)) {
        batch.update(d.reference, {'status': status});
      }
    }

    if (item.commentExists) {
      final commentRef =
          _db.collection(ForumService.commentsCollection).doc(item.commentId);
      if (violation) {
        batch.update(commentRef, {'isActive': false});
      } else if (item.status == ReportStatus.violation) {
        batch.update(commentRef, {'isActive': true});
      }
    }
    await batch.commit();
  }

  // ---------------- Nội bộ ----------------

  Future<Map<String, Map<String, dynamic>>> _loadComments(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    // Firestore không cho truy vấn documentId rỗng
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length ? list.length : i + _whereInLimit;
      final snap = await _db
          .collection(ForumService.commentsCollection)
          .where(FieldPath.documentId, whereIn: list.sublist(i, end))
          .get();
      for (final d in snap.docs) {
        out[d.id] = d.data();
      }
    }
    return out;
  }

  /// Hỗ trợ cả hai kiểu: doc id = Users.id hoặc field 'id' = Users.id.
  Future<Map<String, Map<String, dynamic>>> _loadUsers(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    // Firestore không cho truy vấn documentId rỗng
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length ? list.length : i + _whereInLimit;
      final chunk = list.sublist(i, end);
      final byDocId = _db
          .collection(ForumService.usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final byField = _db
          .collection(ForumService.usersCollection)
          .where('id', whereIn: chunk)
          .get();
      for (final d in (await byDocId).docs) {
        out[d.id] = d.data();
      }
      for (final d in (await byField).docs) {
        final key = d.data()['id']?.toString();
        if (key != null) out.putIfAbsent(key, () => d.data());
      }
    }
    return out;
  }

  String _userName(Map<String, dynamic>? u, {String fallback = 'Ẩn danh'}) {
    final n = u?['fullName'] ?? u?['fullname'] ?? u?['name'];
    return (n == null || n.toString().isEmpty) ? fallback : n.toString();
  }
}