// lib/services/comment_report_service.dart
// Admin kiểm duyệt báo cáo bình luận (collection: commentreport).
// Phía sinh viên gửi báo cáo nằm trong ForumService.reportComment().
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/services/forum_service.dart';

class ReportStatus {
  static const String pending = 'pending';
  static const String notViolation = 'not_violation';
  static const String violation = 'violation';

  /// Chỉ dùng để hiển thị: báo cáo đang chờ nhưng nội dung đã bị xóa.
  /// Không ghi xuống Firestore.
  static const String contentRemoved = 'content_removed';
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

  /// Bình luận đang bị admin ẩn
  final bool commentHidden;
  final String? requestId;

  final String reporterId;
  final String reporterName;

  final bool postHidden;

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
    this.commentHidden = false,
    this.requestId,
    this.postHidden = false,
  });

  bool get effectivelyHidden => commentHidden || postHidden;
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
  /// Báo cáo đang chờ mà bình luận đã bị xóa được trả về với status = contentRemoved.
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

    final hiddenPosts = await _loadHiddenPostIds(comments.values
        .map((c) => c['requestId']?.toString() ?? '')
        .toSet());

    final users = await _loadUsers(userIds);

    final items = reports.map((e) {
      final m = e.value;
      final commentId = m['commentId']?.toString() ?? '';
      final c = comments[commentId];
      final studentId = m['studentId']?.toString() ?? '';

      final removed = c == null || c['isActive'] == false;
      final raw = (m['status']?.toString().isNotEmpty ?? false)
          ? m['status'].toString()
          : ReportStatus.pending;
      // Chỉ báo cáo đang chờ mới đổi; báo cáo admin đã chốt thì giữ nguyên.
      final status =
          (raw == ReportStatus.pending && removed) ? ReportStatus.contentRemoved : raw;

      return ReportItem(
        id: e.key,
        reason: m['reason']?.toString() ?? '',
        status: status,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        commentId: commentId,
        commentExists: c != null,
        commentContent: c?['content']?.toString() ?? '[Bình luận không còn tồn tại]',
        commentActive: c == null ? false : c['isActive'] != false,
        commentHidden: c?['isHidden'] == true,
        postHidden: hiddenPosts.contains(c?['requestId']?.toString()),
        requestId: c?['requestId']?.toString(),
        reporterId: studentId,
        reporterName: _userName(users[studentId], fallback: studentId),
      );
    }).toList();

    items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return items;
  }

  /// Admin xử lý một báo cáo ĐANG CHỜ (đã xử lý rồi thì không đổi nữa — muốn đổi thì
  /// dùng ẩn/hiện bình luận). Quyết định áp dụng cho cả bình luận, nên tất cả báo cáo
  /// đang chờ của cùng bình luận được chốt cùng một kết quả:
  /// - violation = true : báo cáo -> "vi phạm", bình luận bị ẩn (isHidden = true):
  ///   người dùng khác không thấy, admin vẫn thấy ở dạng mờ.
  /// - violation = false: báo cáo -> "không vi phạm", bình luận giữ nguyên.
  Future<void> resolve(ReportItem item, {required bool violation}) async {
    _uid; // bắt buộc đăng nhập

    final fresh = await _db.collection(reportsCollection).doc(item.id).get();
    if (!fresh.exists) throw ForumException('Báo cáo không còn tồn tại');
    final current = fresh.data()?['status']?.toString() ?? ReportStatus.pending;
    if (current != ReportStatus.pending) {
      throw ForumException('Báo cáo này đã được xử lý');
    }

    // Bình luận thuộc bài viết đang ẩn thì chưa xử lý được
    final cDoc =
        await _db.collection(ForumService.commentsCollection).doc(item.commentId).get();
    final rid = cDoc.data()?['requestId']?.toString() ?? '';
    if (rid.isNotEmpty) {
      final post = await _db.collection(ForumService.requestsCollection).doc(rid).get();
      if (post.data()?['isHidden'] == true) {
        throw ForumException(
            'Bài viết đang bị ẩn. Hãy hiện lại bài viết trước khi xử lý bình luận.');
      }
    }

    final status = violation ? ReportStatus.violation : ReportStatus.notViolation;
    final same = await _db
        .collection(reportsCollection)
        .where('commentId', isEqualTo: item.commentId)
        .get();

    final batch = _db.batch();
    for (final d in same.docs) {
      final st = d.data()['status']?.toString() ?? ReportStatus.pending;
      if (st == ReportStatus.pending) batch.update(d.reference, {'status': status});
    }
    if (violation && item.commentExists) {
      batch.update(
        _db.collection(ForumService.commentsCollection).doc(item.commentId),
        {'isHidden': true},
      );
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

  /// Trong các bài [ids], trả về id những bài đang bị admin ẩn.
  Future<Set<String>> _loadHiddenPostIds(Set<String> ids) async {
    final out = <String>{};
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length ? list.length : i + _whereInLimit;
      final snap = await _db
          .collection(ForumService.requestsCollection)
          .where(FieldPath.documentId, whereIn: list.sublist(i, end))
          .get();
      for (final d in snap.docs) {
        if (d.data()['isHidden'] == true) out.add(d.id);
      }
    }
    return out;
  }
}