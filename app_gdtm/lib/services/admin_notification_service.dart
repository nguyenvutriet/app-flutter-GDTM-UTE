// lib/services/admin_notification_service.dart
// Thông báo hệ thống dành riêng cho admin (collection MỚI: adminnotification),
// tách hẳn khỏi collection 'notification' và NotificationService cũ.
//
// Thông báo được tạo tự động khi người dùng báo cáo bài viết / bình luận
// (ForumService._notifyAdmins). Admin nhận realtime bằng Stream.
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotification {
  static const String postReport = 'POST_REPORT';
  static const String commentReport = 'COMMENT_REPORT';

  final String id;
  final String type;
  final String title;
  final String content;

  /// Bài viết liên quan (với báo cáo bình luận là bài chứa bình luận đó)
  final String? requestId;

  /// Id bài viết (POST_REPORT) hoặc id bình luận (COMMENT_REPORT) bị báo cáo
  final String? targetId;
  final String? reportId;
  final bool isRead;
  final DateTime? createdAt;

  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.requestId,
    this.targetId,
    this.reportId,
    this.isRead = false,
    this.createdAt,
  });

  bool get isPostReport => type == postReport;

  factory AdminNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AdminNotification(
      id: d.id,
      type: m['type']?.toString() ?? '',
      title: m['title']?.toString() ?? 'Thông báo',
      content: m['content']?.toString() ?? '',
      requestId: m['requestId']?.toString(),
      targetId: m['targetId']?.toString(),
      reportId: m['reportId']?.toString(),
      isRead: m['isRead'] == true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminNotificationService {
  static const String collection = 'adminnotification';

  final FirebaseFirestore _db;

  AdminNotificationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(collection);

  /// Danh sách thông báo, cập nhật realtime (mới nhất trước).
  Stream<List<AdminNotification>> watch({int limit = 100}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AdminNotification.fromDoc).toList());

  /// Số thông báo chưa đọc, cập nhật realtime (cho bubble).
  Stream<int> watchUnreadCount() => _col
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> setRead(String id, bool isRead) =>
      _col.doc(id).update({'isRead': isRead});

  Future<void> markAllRead() async {
    final snap = await _col.where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}