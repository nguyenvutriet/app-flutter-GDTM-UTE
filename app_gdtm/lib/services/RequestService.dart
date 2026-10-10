import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/ClarificationConversation.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Message.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/RequestStatusHistory.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/services/CloudinaryService.dart';
import 'package:app_gdtm/utils/file_picker_compat.dart';

import 'feedback_status.dart';

/// Kiểu riêng tư khi gửi góp ý.
enum FeedbackPrivacy {
  /// Chỉ gửi đến phòng ban, không đăng diễn đàn.
  department,

  /// Gửi công khai, đăng lên diễn đàn.
  public,
}

class RequestService {
  // ------------------------------------------------------------
  // TODO: đối chiếu với tên collection / giá trị thực tế trên Firestore
  // ------------------------------------------------------------
  static const String requestsCollection = 'requests';
  static const String fileAttachmentsCollection = 'fileattachments';
  static const String statusHistoryCollection = 'requeststatushistory';
  static const String notificationsCollection = 'notification';

  /// Trạng thái xử lý ban đầu của góp ý.
  static const String initialStatus = 'PENDING';

  /// Giá trị postStatus theo quyền riêng tư.
  static const String postStatusPrivate = 'PRIVATE';
  static const String postStatusPublic = 'PUBLIC';

  static const int maxFileBytes = 20 * 1024 * 1024; // 20MB / tệp
  static const int maxTotalBytes = 40 * 1024 * 1024; // 40MB / tổng

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  final FeedbackStatusContext _statusContext = FeedbackStatusContext();

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Đang chờ tiếp nhận';
      case 'APPROVED':
        return 'Đang xử lý';
      case 'RESOLVED':
        return 'Đã xử lý';
      case 'REJECTED':
        return 'Từ chối';
      case 'FORWARDING':
        return 'Đã được chuyển tiếp';
      default:
        return status;
    }
  }

  /// Phòng ban mặc định khi sinh viên để trống: Phòng CTSV.
  /// Tìm theo tên có chứa "CTSV" hoặc "công tác sinh viên".
  static String? defaultDepartmentId(List<Department> departments) {
    for (final d in departments) {
      final name = (d.name ?? '').toLowerCase();
      if (name.contains('ctsv') || name.contains('công tác sinh viên')) {
        return d.id;
      }
    }
    return null;
  }

  /// Gửi góp ý:
  ///  1. Upload từng tệp lên Cloudinary.
  ///  2. Ghi (batch) request + fileAttachments + status history + notification
  ///     cho phòng ban lên Firestore.
  ///
  /// Upload trước, ghi Firestore sau để nếu upload lỗi thì không tạo
  /// góp ý "mồ côi". Trả về id góp ý vừa tạo.
  Future<String> submitFeedback({
    required Users user,
    required String subject,
    required String description,
    required String departmentId,
    required List<String> categoryIds,
    required FeedbackPrivacy privacy,
    String? location,
    List<PlatformFile> files = const [],
    void Function(int done, int total)? onUploadProgress,
  }) async {
    final requestRef = _firestore.collection(requestsCollection).doc();
    final requestId = requestRef.id;
    final now = DateTime.now();

    // 1. Upload lên Cloudinary
    final attachments = <FileAttachment>[];
    final publicIds = <String, String>{}; // attachmentId -> public_id
    final resourceTypes = <String, String>{};
    final deleteTokens = <String, String?>{};

    for (var i = 0; i < files.length; i++) {
      onUploadProgress?.call(i, files.length);
      final f = files[i];
      final result = await _cloudinary.uploadFile(f);

      final attachRef = _firestore.collection(fileAttachmentsCollection).doc();
      attachments.add(
        FileAttachment(
          id: attachRef.id,
          filename: f.name,
          fileUrl: result.secureUrl,
          filestype: _extensionOf(f.name),
          filesize: result.bytes,
          createat: now,
          requestId: requestId,
        ),
      );
      publicIds[attachRef.id] = result.publicId;
      resourceTypes[attachRef.id] = result.resourceType;
      deleteTokens[attachRef.id] = result.deleteToken;
    }
    onUploadProgress?.call(files.length, files.length);

    // 2. Ghi Firestore
    final request = Request(
      id: requestId,
      subject: subject.trim(),
      description: description.trim(),
      location: (location ?? '').trim().isEmpty ? null : location!.trim(),
      currentStatus: initialStatus,
      postStatus: privacy == FeedbackPrivacy.public
          ? postStatusPublic
          : postStatusPrivate,
      departmentId: departmentId,
      userId: user.id,
      timeCreate: now,
    );

    final batch = _firestore.batch();

    batch.set(requestRef, {
      ...request.toFirestore(),
      // Model Request chưa có trường này; lưu danh sách id danh mục đã chọn.
      'categoryIds': categoryIds,
    });

    for (final a in attachments) {
      batch.set(_firestore.collection(fileAttachmentsCollection).doc(a.id), {
        ...a.toFirestore(),
        // Cần public_id nếu sau này muốn xoá/biến đổi file trên Cloudinary.
        'publicId': publicIds[a.id],
        'resourceType': resourceTypes[a.id],
        'deleteToken': deleteTokens[a.id],
      });
    }

    final historyRef = _firestore.collection(statusHistoryCollection).doc();
    batch.set(historyRef, {
      'id': historyRef.id,
      'status': initialStatus,
      'createAt': Timestamp.fromDate(now),
      'requestId': requestId,
    });

    final departmentNotificationRef = _firestore
        .collection(notificationsCollection)
        .doc();
    batch.set(departmentNotificationRef, {
      'id': departmentNotificationRef.id,
      'title': 'Có góp ý mới cần tiếp nhận',
      'content':
          '${user.fullName ?? user.id ?? 'Sinh viên'} đã gửi góp ý: ${subject.trim()}',
      'notificationType': 'NEW_REQUEST',
      'isRead': false,
      'createAt': Timestamp.fromDate(now),
      'departmentId': departmentId,
      'requestId': requestId,
      'userId': null,
    });

    final userNotificationRef = _firestore
        .collection(notificationsCollection)
        .doc();
    batch.set(userNotificationRef, {
      'id': userNotificationRef.id,
      'title': 'Bạn đã gửi một góp ý',
      'content': 'Góp ý "${subject.trim()}" đã được gửi thành công.',
      'notificationType': 'FEEDBACK_SUBMITTED',
      'isRead': false,
      'createAt': Timestamp.fromDate(now),
      'departmentId': null,
      'requestId': requestId,
      'userId': user.id,
    });

    await batch.commit();
    return requestId;
  }

  Future<void> updateFeedback({
    required Request request,
    required String userId,
    required String subject,
    required String description,
    required String departmentId,
    required List<String> categoryIds,
    required FeedbackPrivacy privacy,
    String? location,
    List<PlatformFile> files = const [],
    Set<String> retainedAttachmentIds = const {},
    void Function(int done, int total)? onUploadProgress,
  }) async {
    final id = request.id;
    if (id == null || id.isEmpty) throw StateError('Góp ý không hợp lệ.');
    final requestRef = _firestore.collection(requestsCollection).doc(id);
    final current = await requestRef.get();
    if (!current.exists ||
        (current.data()?['userId'] as String?) != userId ||
        (current.data()?['currentStatus'] as String?) != initialStatus) {
      throw StateError('Chỉ được cập nhật góp ý đang chờ tiếp nhận.');
    }

    final oldSnapshot = await _firestore
        .collection(fileAttachmentsCollection)
        .where('requestId', isEqualTo: id)
        .get();

    final uploaded = <CloudinaryUploadResult>[];
    try {
      for (var i = 0; i < files.length; i++) {
        onUploadProgress?.call(i, files.length);
        uploaded.add(await _cloudinary.uploadFile(files[i], ownerId: id));
      }
      onUploadProgress?.call(files.length, files.length);
    } catch (_) {
      for (final item in uploaded) {
        if (item.deleteToken != null) {
          await _cloudinary.deleteByToken(item.deleteToken!);
        }
      }
      rethrow;
    }

    final batch = _firestore.batch();
    batch.update(requestRef, {
      'subject': subject.trim(),
      'description': description.trim(),
      'location': (location ?? '').trim().isEmpty ? null : location!.trim(),
      'departmentId': departmentId,
      'categoryIds': categoryIds,
      'postStatus': privacy == FeedbackPrivacy.public
          ? postStatusPublic
          : postStatusPrivate,
    });

    final removedAttachments = oldSnapshot.docs
        .where((doc) => !retainedAttachmentIds.contains(doc.id))
        .toList();
    final attachmentsChanged =
        files.isNotEmpty ||
        retainedAttachmentIds.length != oldSnapshot.docs.length;
    if (attachmentsChanged) {
      for (final doc in removedAttachments) {
        batch.delete(doc.reference);
      }
      final now = DateTime.now();
      for (final item in uploaded) {
        final ref = _firestore.collection(fileAttachmentsCollection).doc();
        batch.set(ref, {
          'id': ref.id,
          'filename': item.fileName,
          'fileUrl': item.secureUrl,
          'filestype': item.fileType,
          'filesize': item.bytes,
          'createat': Timestamp.fromDate(now),
          'requestId': id,
          'publicId': item.publicId,
          'resourceType': item.resourceType,
          'deleteToken': item.deleteToken,
        });
      }
    }
    await batch.commit();

    if (attachmentsChanged) {
      for (final doc in removedAttachments) {
        final data = doc.data();
        final token = data['deleteToken'] as String?;
        if (token != null && token.isNotEmpty) {
          await _cloudinary.deleteByToken(token);
        }
      }
    }
  }

  Future<void> deleteFeedback(
    String requestId, {
    required String userId,
  }) async {
    final requestRef = _firestore.collection(requestsCollection).doc(requestId);
    final request = await requestRef.get();
    if (!request.exists ||
        (request.data()?['userId'] as String?) != userId ||
        (request.data()?['currentStatus'] as String?) != initialStatus) {
      throw StateError('Chỉ được xóa góp ý đang chờ tiếp nhận.');
    }
    final attachments = await _firestore
        .collection(fileAttachmentsCollection)
        .where('requestId', isEqualTo: requestId)
        .get();
    final notifications = await _firestore
        .collection(notificationsCollection)
        .where('requestId', isEqualTo: requestId)
        .get();
    final batch = _firestore.batch();
    batch.delete(requestRef);
    for (final doc in attachments.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    for (final doc in attachments.docs) {
      final token = doc.data()['deleteToken'] as String?;
      if (token != null && token.isNotEmpty) {
        await _cloudinary.deleteByToken(token);
      }
    }
  }

  Future<List<Request>> getStudentFeedbackHistory(String userId) async {
    final snapshot = await _firestore
        .collection(requestsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final requests = snapshot.docs.map(Request.fromFirestore).toList();
    requests.sort((a, b) {
      final aTime = a.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return requests;
  }

  Future<FeedbackDetails> getFeedbackDetails(Request request) async {
    final requestId = request.id;
    if (requestId == null || requestId.isEmpty) {
      return const FeedbackDetails();
    }

    final results = await Future.wait([
      _firestore
          .collection(statusHistoryCollection)
          .where('requestId', isEqualTo: requestId)
          .get(),
      _firestore
          .collection(fileAttachmentsCollection)
          .where('requestId', isEqualTo: requestId)
          .get(),
      _firestore
          .collection('clarificationconversation')
          .where('requestId', isEqualTo: requestId)
          .get(),
    ]);

    final histories =
        (results[0] as QuerySnapshot).docs
            .map(RequestStatusHistory.fromFirestore)
            .toList()
          ..sort(
            (a, b) => (a.createAt ?? DateTime(0)).compareTo(
              b.createAt ?? DateTime(0),
            ),
          );
    final attachments = (results[1] as QuerySnapshot).docs
        .map(FileAttachment.fromFirestore)
        .toList();
    final conversations =
        (results[2] as QuerySnapshot).docs
            .map(ClarificationConversation.fromFirestore)
            .toList()
          ..sort(
            (a, b) => (b.createAt ?? DateTime(0)).compareTo(
              a.createAt ?? DateTime(0),
            ),
          );

    final conversationsWithMessages = await Future.wait(
      conversations.map((conversation) async {
        final conversationId = conversation.id;
        if (conversationId == null || conversationId.isEmpty) {
          return conversation;
        }
        final messages = await _firestore
            .collection('message')
            .where('clarificationConversationId', isEqualTo: conversationId)
            .get();
        final ordered = messages.docs.map(Message.fromFirestore).toList()
          ..sort(
            (a, b) => (a.createAt ?? DateTime(0)).compareTo(
              b.createAt ?? DateTime(0),
            ),
          );
        return ClarificationConversation(
          id: conversation.id,
          isOpen: conversation.isOpen,
          subject: conversation.subject,
          createAt: conversation.createAt,
          requestId: conversation.requestId,
          messages: ordered,
        );
      }),
    );

    return FeedbackDetails(
      histories: histories,
      attachments: attachments,
      conversations: conversationsWithMessages,
    );
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  Stream<List<Request>> watchStaffFeedbacks({
    required String role,
    String? departmentId,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      requestsCollection,
    );

    if (role != 'ROLE_ADMIN') {
      if (departmentId == null || departmentId.trim().isEmpty) {
        return Stream.value([]);
      }

      query = query.where('departmentId', isEqualTo: departmentId);
    }

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => Request.fromFirestore(doc))
          .toList();

      return requests;
    });
  }
  // ============================================================
  // STAFF - LẤY DANH SÁCH GÓP Ý
  // ============================================================

  Future<List<Request>> getStaffFeedbacks({
    required String role,
    String? departmentId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      requestsCollection,
    );

    // ADMIN xem tất cả
    if (role != 'ROLE_ADMIN') {
      if (departmentId == null || departmentId.trim().isEmpty) {
        return [];
      }

      // STAFF chỉ xem request thuộc phòng ban mình
      query = query.where('departmentId', isEqualTo: departmentId);
    }

    final snapshot = await query.get();

    final requests = snapshot.docs
        .map((doc) => Request.fromFirestore(doc))
        .toList();

    // Sort mới nhất trước
    requests.sort((a, b) {
      final aTime = a.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bTime = b.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return requests;
  }

  // ============================================================
  // STAFF - DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getStaffDashboard({
    required String role,
    String? departmentId,
  }) async {
    try {
      // Lấy danh sách request theo quyền của Staff/Admin
      final requests = await getStaffFeedbacks(
        role: role,
        departmentId: departmentId,
      );

      int pending = 0;
      int approved = 0;
      int resolved = 0;
      int rejected = 0;
      int forwarding = 0;

      for (final request in requests) {
        switch (request.currentStatus) {
          case 'PENDING':
            pending++;
            break;

          case 'APPROVED':
            approved++;
            break;

          case 'RESOLVED':
            resolved++;
            break;

          case 'REJECTED':
            rejected++;
            break;

          case 'FORWARDING':
            forwarding++;
            break;
        }
      }

      return {
        'total': requests.length,
        'pending': pending,
        'approved': approved,
        'resolved': resolved,
        'rejected': rejected,
        'forwarding': forwarding,

        // Lấy tối đa 5 request mới nhất
        'recentRequests': requests.take(5).toList(),
      };
    } catch (e) {
      print('Lỗi getStaffDashboard: $e');

      rethrow;
    }
  }

  // ============================================================
  // STAFF - TÌM KIẾM
  // ============================================================

  Future<List<Request>> searchStaffFeedbacks({
    required String keyword,
    required String role,
    String? departmentId,
  }) async {
    final requests = await getStaffFeedbacks(
      role: role,
      departmentId: departmentId,
    );

    final value = keyword.trim().toLowerCase();

    if (value.isEmpty) {
      return requests;
    }

    return requests.where((request) {
      final subject = request.subject?.toLowerCase() ?? '';

      final description = request.description?.toLowerCase() ?? '';

      final location = request.location?.toLowerCase() ?? '';

      return subject.contains(value) ||
          description.contains(value) ||
          location.contains(value);
    }).toList();
  }

  // ============================================================
  // STAFF - LỌC STATUS
  // ============================================================

  Future<List<Request>> filterStaffByStatus({
    required String status,
    required String role,
    String? departmentId,
  }) async {
    if (status == 'ALL') {
      return getStaffFeedbacks(role: role, departmentId: departmentId);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection(requestsCollection)
        .where('currentStatus', isEqualTo: status);

    if (role != 'ROLE_ADMIN') {
      if (departmentId == null || departmentId.trim().isEmpty) {
        return [];
      }

      query = query.where('departmentId', isEqualTo: departmentId);
    }

    final snapshot = await query.get();

    final requests = snapshot.docs
        .map((doc) => Request.fromFirestore(doc))
        .toList();

    requests.sort((a, b) {
      final aTime = a.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bTime = b.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return requests;
  }

  // ============================================================
  // STAFF - LỌC CATEGORY
  // ============================================================

  Future<List<Request>> filterStaffByCategory({
    required String categoryId,
    required String role,
    String? departmentId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(requestsCollection)
        .where('categoryIds', arrayContains: categoryId);

    if (role != 'ROLE_ADMIN') {
      if (departmentId == null || departmentId.trim().isEmpty) {
        return [];
      }

      query = query.where('departmentId', isEqualTo: departmentId);
    }

    final snapshot = await query.get();

    final requests = snapshot.docs
        .map((doc) => Request.fromFirestore(doc))
        .toList();

    requests.sort((a, b) {
      final aTime = a.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bTime = b.timeCreate ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return requests;
  }

  // ============================================================
  // STAFF - CẬP NHẬT TRẠNG THÁI
  // ============================================================

  Future<void> updateStaffStatus({
    required String requestId,
    required String newStatus,
    required String staffUserId,
  }) async {
    final requestRef = _firestore.collection(requestsCollection).doc(requestId);

    final snapshot = await requestRef.get();

    if (!snapshot.exists) {
      throw StateError('Không tìm thấy góp ý.');
    }

    final request = Request.fromFirestore(snapshot);

    final currentStatus = request.currentStatus;

    // Kiểm tra State Pattern
    if (!_statusContext.canChange(currentStatus, newStatus)) {
      throw StateError(
        'Không thể chuyển từ '
        '$currentStatus sang $newStatus.',
      );
    }

    final now = DateTime.now();

    final historyRef = _firestore.collection(statusHistoryCollection).doc();

    final batch = _firestore.batch();

    // ----------------------------------------------------------
    // 1. Update request
    // ----------------------------------------------------------

    batch.update(requestRef, {'currentStatus': newStatus});

    // ----------------------------------------------------------
    // 2. Create status history
    // ----------------------------------------------------------

    batch.set(historyRef, {
      'id': historyRef.id,
      'status': newStatus,
      'createAt': Timestamp.fromDate(now),
      'requestId': requestId,
    });

    // ----------------------------------------------------------
    // 3. Notification cho sinh viên
    // ----------------------------------------------------------

    final notificationRef = _firestore
        .collection(notificationsCollection)
        .doc();

    batch.set(notificationRef, {
      'id': notificationRef.id,

      'title': 'Cập nhật trạng thái góp ý',

      'content':
          'Góp ý "${request.subject ?? ''}" '
          'đã chuyển sang trạng thái '
          '${_statusLabel(newStatus)}.',

      'notificationType': 'REQUEST_STATUS_CHANGED',

      'isRead': false,

      'createAt': Timestamp.fromDate(now),

      'departmentId': request.departmentId,

      'requestId': requestId,

      'userId': request.userId,
    });

    await batch.commit();
  }

  // ============================================================
  // STAFF - FORWARD REQUEST
  // ============================================================

  Future<void> forwardRequest({
    required String requestId,
    required String toDepartmentId,
    required String staffUserId,
    String? note,
  }) async {
    final requestRef = _firestore.collection(requestsCollection).doc(requestId);

    final snapshot = await requestRef.get();

    if (!snapshot.exists) {
      throw StateError('Không tìm thấy góp ý.');
    }

    final request = Request.fromFirestore(snapshot);

    final fromDepartmentId = request.departmentId;

    if (fromDepartmentId == toDepartmentId) {
      throw StateError('Không thể chuyển đến cùng phòng ban.');
    }

    final now = DateTime.now();

    final historyRef = _firestore.collection(statusHistoryCollection).doc();

    final batch = _firestore.batch();

    // ----------------------------------------------------------
    // 1. Chuyển phòng ban
    // ----------------------------------------------------------

    batch.update(requestRef, {
      'departmentId': toDepartmentId,

      // Sau khi chuyển:
      // PENDING
      'currentStatus': 'PENDING',
    });

    // ----------------------------------------------------------
    // 2. Status history
    // ----------------------------------------------------------

    batch.set(historyRef, {
      'id': historyRef.id,

      'status': 'FORWARDING',

      'createAt': Timestamp.fromDate(now),

      'requestId': requestId,
    });

    // ----------------------------------------------------------
    // 3. Notification phòng ban mới
    // ----------------------------------------------------------

    final notificationRef = _firestore
        .collection(notificationsCollection)
        .doc();

    batch.set(notificationRef, {
      'id': notificationRef.id,

      'title': 'Có góp ý được chuyển đến',

      'content':
          'Góp ý "${request.subject ?? ''}" '
          'đã được chuyển đến phòng ban.',

      'notificationType': 'REQUEST_FORWARDED',

      'isRead': false,

      'createAt': Timestamp.fromDate(now),

      'departmentId': toDepartmentId,

      'requestId': requestId,

      'userId': null,

      'fromDepartmentId': fromDepartmentId,

      'forwardedBy': staffUserId,

      'note': note ?? '',
    });

    await batch.commit();
  }
}

class FeedbackDetails {
  final List<RequestStatusHistory> histories;
  final List<FileAttachment> attachments;
  final List<ClarificationConversation> conversations;

  const FeedbackDetails({
    this.histories = const [],
    this.attachments = const [],
    this.conversations = const [],
  });
}
