import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/services/CloudinaryService.dart';

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

  /// Trạng thái xử lý ban đầu của góp ý.
  static const String initialStatus = 'PENDING';

  /// Giá trị postStatus theo quyền riêng tư.
  static const String postStatusPrivate = 'PRIVATE';
  static const String postStatusPublic = 'PUBLIC';

  static const int maxFileBytes = 20 * 1024 * 1024; // 20MB / tệp
  static const int maxTotalBytes = 40 * 1024 * 1024; // 40MB / tổng

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

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
  ///  2. Ghi (batch) request + fileAttachments + status history lên Firestore.
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

    for (var i = 0; i < files.length; i++) {
      onUploadProgress?.call(i, files.length);
      final f = files[i];
      final result = await _cloudinary.uploadFile(f);

      final attachRef =
          _firestore.collection(fileAttachmentsCollection).doc();
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
      batch.set(
        _firestore.collection(fileAttachmentsCollection).doc(a.id),
        {
          ...a.toFirestore(),
          // Cần public_id nếu sau này muốn xoá/biến đổi file trên Cloudinary.
          'publicId': publicIds[a.id],
          'resourceType': resourceTypes[a.id],
        },
      );
    }

    final historyRef = _firestore.collection(statusHistoryCollection).doc();
    batch.set(historyRef, {
      'id': historyRef.id,
      'status': initialStatus,
      'createAt': Timestamp.fromDate(now),
      'requestId': requestId,
    });

    await batch.commit();
    return requestId;
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}