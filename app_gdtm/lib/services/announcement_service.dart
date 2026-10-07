// lib/services/announcement_service.dart
// Thông báo: xem danh sách (mọi role) và đăng thông báo (giảng viên).
// Tệp đính kèm (pdf, doc, docx, xls, xlsx) upload lên Cloudinary, lưu metadata ở
// collection fileattachments với announcementId (giống cách góp ý lưu requestId).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'package:app_gdtm/models/Announcement.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/services/CloudinaryService.dart';
import 'package:app_gdtm/services/RequestService.dart';

class AnnouncementException implements Exception {
  final String message;
  AnnouncementException(this.message);
  @override
  String toString() => message;
}

/// Một trang thông báo khi tải phân trang (lazy loading).
class AnnouncementPage {
  final List<AnnouncementItem> items;

  /// Con trỏ để tải trang kế tiếp (truyền vào startAfter).
  final DocumentSnapshot? lastDoc;

  /// Còn dữ liệu để tải tiếp hay không.
  final bool hasMore;

  const AnnouncementPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class AnnouncementService {
  static const String announcementsCollection = 'announcement';
  static const String attachmentsCollection =
      RequestService.fileAttachmentsCollection;
  static const String usersCollection = 'users';
  static const String departmentsCollection = 'department';

  /// Định dạng tệp được phép đính kèm
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];

  static const int _whereInLimit = 30;

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary = CloudinaryService();
  final String? Function() _getCurrentUserId;

  /// [currentUserId]: Users.id của người đang đăng nhập (null nếu chưa đăng nhập).
  AnnouncementService({
    required String? Function() currentUserId,
    FirebaseFirestore? db,
  }) : _getCurrentUserId = currentUserId,
       _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final id = _getCurrentUserId();
    if (id == null || id.isEmpty) {
      throw AnnouncementException('Chưa đăng nhập!');
    }
    return id;
  }

  // ==================================================================
  // XEM
  // ==================================================================

  /// Thông báo chung (mọi role xem được), mới nhất trước.
  Future<List<AnnouncementItem>> getAnnouncements({int limit = 50}) async {
    _uid;
    final snap = await _db
        .collection(announcementsCollection)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return _build(snap.docs);
  }

  /// Tải thông báo theo từng trang (lazy loading).
  ///
  /// - [startAfter]: [AnnouncementPage.lastDoc] của trang trước (null = trang đầu).
  /// - [from] / [to]: lọc khoảng thời gian ngay trên Firestore ([from] <= date < [to]).
  ///   Lọc và sắp xếp cùng trường 'date' nên không cần composite index.
  /// - [descending]: true = mới nhất trước.
  Future<AnnouncementPage> getAnnouncementsPage({
    int limit = 15,
    DocumentSnapshot? startAfter,
    DateTime? from,
    DateTime? to,
    bool descending = true,
  }) async {
    _uid;
    Query<Map<String, dynamic>> q = _db.collection(announcementsCollection);
    if (from != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(to));
    }
    q = q.orderBy('date', descending: descending);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.limit(limit).get();
    final items = await _build(snap.docs);
    return AnnouncementPage(
      items: items,
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length >= limit,
    );
  }

  /// Toàn bộ thông báo announcement dành cho sinh viên xem.
  Future<List<AnnouncementItem>> getDepartmentAnnouncements({int limit = 50}) {
    return getAnnouncements(limit: limit);
  }

  /// Toàn bộ phòng ban trong CSDL (bỏ phòng ban bị tắt isActive == false
  /// và phòng ban không có tên), sắp xếp theo tên.
  Future<List<Department>> getAllDepartments() async {
    _uid;
    final snap = await _db.collection(departmentsCollection).get();
    final list = snap.docs
        .map((d) => Department.fromFirestore(d))
        .where((d) => d.isActive != false)
        .where((d) => (d.name ?? '').trim().isNotEmpty)
        .toList();
    list.sort((a, b) => a.name!.trim().compareTo(b.name!.trim()));
    return list;
  }

  /// Thông báo do người đang đăng nhập đăng (cho trang quản lý).
  /// Sắp xếp phía client để không cần composite index.
  Future<List<AnnouncementItem>> getMyAnnouncements() async {
    final uid = _uid;
    final snap = await _db
        .collection(announcementsCollection)
        .where('userId', isEqualTo: uid)
        .get();
    final items = await _build(snap.docs);
    items.sort((a, b) => _cmpDate(b.date, a.date));
    return items;
  }

  // ==================================================================
  // ĐĂNG
  // ==================================================================

  /// Đăng thông báo mới. Upload tệp trước, ghi Firestore sau (batch) để
  /// upload lỗi thì không tạo thông báo "mồ côi". Trả về id thông báo.
  Future<String> createAnnouncement({
    required String title,
    required String content,
    List<PlatformFile> files = const [],
    void Function(int done, int total)? onUploadProgress,
  }) async {
    final uid = _uid;
    final t = title.trim();
    final c = content.trim();
    if (t.isEmpty || c.isEmpty) {
      throw AnnouncementException('Vui lòng nhập tiêu đề và nội dung.');
    }

    // Kiểm tra tệp
    var total = 0;
    for (final f in files) {
      if (!allowedExtensions.contains(_extensionOf(f.name))) {
        throw AnnouncementException(
          '"${f.name}" không đúng định dạng (chỉ pdf, word, excel).',
        );
      }
      if (f.size > RequestService.maxFileBytes) {
        throw AnnouncementException('"${f.name}" vượt quá 20MB.');
      }
      total += f.size;
    }
    if (total > RequestService.maxTotalBytes) {
      throw AnnouncementException('Tổng dung lượng tệp vượt quá 40MB.');
    }

    final ref = _db.collection(announcementsCollection).doc();
    final now = DateTime.now();

    // 1. Upload lên Cloudinary
    final attachments = <FileAttachment>[];
    final publicIds = <String, String>{};
    final resourceTypes = <String, String>{};

    for (var i = 0; i < files.length; i++) {
      onUploadProgress?.call(i, files.length);
      final f = files[i];
      final result = await _cloudinary.uploadFile(f);
      final attachRef = _db.collection(attachmentsCollection).doc();
      attachments.add(
        FileAttachment(
          id: attachRef.id,
          filename: f.name,
          fileUrl: result.secureUrl,
          filestype: _extensionOf(f.name),
          filesize: result.bytes,
          createat: now,
          announcementId: ref.id,
        ),
      );
      publicIds[attachRef.id] = result.publicId;
      resourceTypes[attachRef.id] = result.resourceType;
    }
    onUploadProgress?.call(files.length, files.length);

    // 2. Ghi Firestore
    final batch = _db.batch();
    batch.set(
      ref,
      Announcement(
        id: ref.id,
        title: t,
        content: c,
        date: now,
        userId: uid,
      ).toFirestore(),
    );
    for (final a in attachments) {
      batch.set(_db.collection(attachmentsCollection).doc(a.id), {
        ...a.toFirestore(),
        'publicId': publicIds[a.id],
        'resourceType': resourceTypes[a.id],
      });
    }
    await batch.commit();
    return ref.id;
  }

  // ==================================================================
  // NỘI BỘ
  // ==================================================================

  Future<List<AnnouncementItem>> _build(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    final ids = docs.map((d) => d.id).toList();
    final authorIds = docs
        .map((d) => d.data()['userId'])
        .whereType<String>()
        .toSet();

    final attachF = _whereIn(attachmentsCollection, 'announcementId', ids);
    final usersF = _loadUsers(authorIds);
    final attachDocs = await attachF;
    final users = await usersF;

    final deptIds = users.values
        .map((u) => u['departmentId'])
        .whereType<String>()
        .toSet();
    final departments = await _loadDepartments(deptIds);

    final attachBy = <String, List<FileAttachment>>{};
    for (final d in attachDocs) {
      final a = FileAttachment.fromFirestore(d);
      final key = a.announcementId;
      if (key != null) attachBy.putIfAbsent(key, () => []).add(a);
    }
    for (final list in attachBy.values) {
      list.sort((a, b) => _cmpDate(a.createat, b.createat));
    }

    return docs.map((d) {
      final base = Announcement.fromFirestore(d);
      final u = users[base.userId];
      final deptId = u?['departmentId']?.toString();
      return AnnouncementItem(
        announcement: Announcement(
          id: d.id,
          title: base.title,
          content: base.content,
          date: base.date,
          userId: base.userId,
          attachments: attachBy[d.id] ?? [],
        ),
        authorName: _userName(u),
        authorRole: u?['role']?.toString() ?? '',
        department: deptId == null ? null : departments[deptId],
      );
    }).toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _whereIn(
    String collection,
    String field,
    List<String> ids,
  ) async {
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < ids.length; i += _whereInLimit) {
      final end = i + _whereInLimit > ids.length
          ? ids.length
          : i + _whereInLimit;
      final snap = await _db
          .collection(collection)
          .where(field, whereIn: ids.sublist(i, end))
          .get();
      out.addAll(snap.docs);
    }
    return out;
  }

  /// Users theo Users.id (doc id hoặc field 'id').
  Future<Map<String, Map<String, dynamic>>> _loadUsers(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length
          ? list.length
          : i + _whereInLimit;
      final chunk = list.sublist(i, end);
      final byDocId = _db
          .collection(usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final byField = _db
          .collection(usersCollection)
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

  Future<Map<String, Department>> _loadDepartments(Set<String> ids) async {
    final out = <String, Department>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final end = i + _whereInLimit > list.length
          ? list.length
          : i + _whereInLimit;
      final chunk = list.sublist(i, end);
      final byDocId = _db
          .collection(departmentsCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final byField = _db
          .collection(departmentsCollection)
          .where('id', whereIn: chunk)
          .get();
      for (final d in (await byDocId).docs) {
        out[d.id] = Department.fromFirestore(d);
      }
      for (final d in (await byField).docs) {
        final dep = Department.fromFirestore(d);
        if (dep.id != null) out.putIfAbsent(dep.id!, () => dep);
      }
    }
    return out;
  }

  String _userName(Map<String, dynamic>? u) {
    final n = u?['fullName'] ?? u?['fullname'] ?? u?['name'];
    return (n == null || n.toString().isEmpty) ? 'Ẩn danh' : n.toString();
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  int _cmpDate(DateTime? a, DateTime? b) =>
      (a ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        b ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}