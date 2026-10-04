// lib/services/post_report_service.dart
// Admin kiểm duyệt báo cáo bài viết (collection: postreport).
// Phía người dùng gửi báo cáo nằm trong ForumService.reportPost();
// ẩn / hiện bài bất kỳ nằm trong ForumService.setPostHidden().
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/comment_report_service.dart' show ReportStatus;
import 'package:app_gdtm/services/forum_service.dart';

export 'package:app_gdtm/services/comment_report_service.dart' show ReportStatus;

/// Một dòng báo cáo bài viết đã gộp sẵn tiêu đề bài, tên người báo cáo...
class PostReportItem {
  final String id;
  final String reason;
  final String status;
  final DateTime? createdAt;

  final String postId;
  final bool postExists;
  final String postTitle;

  /// Bài đang bị admin ẩn
  final bool postHidden;

  final String reporterId;
  final String reporterName;

  const PostReportItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.postId,
    required this.reporterId,
    required this.reporterName,
    this.createdAt,
    this.postExists = true,
    this.postTitle = '',
    this.postHidden = false,
  });
}

class PostReportService {
  static const String reportsCollection = ForumService.postReportsCollection;
  static const int _whereInLimit = 30;

  final FirebaseFirestore _db;
  final String? Function() _getCurrentUserId;

  /// [currentUserId]: Users.id của admin đang đăng nhập.
  PostReportService({
    required String? Function() currentUserId,
    FirebaseFirestore? db,
  })  : _getCurrentUserId = currentUserId,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final id = _getCurrentUserId();
    if (id == null || id.isEmpty) throw ForumException('Chưa đăng nhập!');
    return id;
  }

  /// Tất cả báo cáo bài viết (mới nhất trước).
  Future<List<PostReportItem>> getReports() async {
    _uid;
    final snap = await _db.collection(reportsCollection).get();
    if (snap.docs.isEmpty) return [];

    final reports = snap.docs.map((d) => MapEntry(d.id, d.data())).toList();
    final postIds =
        reports.map((e) => e.value['requestId']).whereType<String>().toSet();
    final userIds =
        reports.map((e) => e.value['studentId']).whereType<String>().toSet();

    final posts = await _loadPosts(postIds);
    final users = await _loadUsers(userIds);

    final items = reports.map((e) {
      final m = e.value;
      final postId = m['requestId']?.toString() ?? '';
      final p = posts[postId];
      final studentId = m['studentId']?.toString() ?? '';
      return PostReportItem(
        id: e.key,
        reason: m['reason']?.toString() ?? '',
        status: (m['status']?.toString().isNotEmpty ?? false)
            ? m['status'].toString()
            : ReportStatus.pending,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        postId: postId,
        postExists: p != null,
        postTitle: p?['subject']?.toString() ?? '[Bài viết không còn tồn tại]',
        postHidden: p?['isHidden'] == true,
        reporterId: studentId,
        reporterName: _userName(users[studentId], fallback: studentId),
      );
    }).toList();

    items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return items;
  }

  /// Admin xử lý một báo cáo ĐANG CHỜ (đã xử lý rồi thì chốt, muốn đổi thì ẩn/hiện bài).
  /// Quyết định áp dụng cho cả bài, nên mọi báo cáo đang chờ của cùng bài được chốt
  /// cùng một kết quả:
  /// - violation = true : -> "vi phạm", bài bị ẩn (isHidden = true).
  /// - violation = false: -> "không vi phạm", bài giữ nguyên.
  Future<void> resolve(PostReportItem item, {required bool violation}) async {
    _uid;

    final fresh = await _db.collection(reportsCollection).doc(item.id).get();
    if (!fresh.exists) throw ForumException('Báo cáo không còn tồn tại');
    final current = fresh.data()?['status']?.toString() ?? ReportStatus.pending;
    if (current != ReportStatus.pending) {
      throw ForumException('Báo cáo này đã được xử lý');
    }

    final status = violation ? ReportStatus.violation : ReportStatus.notViolation;
    final same = await _db
        .collection(reportsCollection)
        .where('requestId', isEqualTo: item.postId)
        .get();

    final batch = _db.batch();
    for (final d in same.docs) {
      final st = d.data()['status']?.toString() ?? ReportStatus.pending;
      if (st == ReportStatus.pending) batch.update(d.reference, {'status': status});
    }
    if (violation && item.postExists) {
      batch.update(
        _db.collection(RequestService.requestsCollection).doc(item.postId),
        {'isHidden': true},
      );
    }
    await batch.commit();
  }

  // ---------------- Nội bộ ----------------

  Future<Map<String, Map<String, dynamic>>> _loadPosts(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length ? list.length : i + _whereInLimit;
      final snap = await _db
          .collection(RequestService.requestsCollection)
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