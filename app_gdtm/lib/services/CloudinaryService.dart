import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

/// Cấu hình Cloudinary.
///
/// Chỉ đặt ở đây cloud name + upload preset (loại UNSIGNED).
/// TUYỆT ĐỐI KHÔNG đưa API Secret vào app Flutter.
class CloudinaryConfig {
  static const String cloudName = 'dvk4nempu';

  static const String uploadPreset = 'GDTM_FLUTTER';

  // Thư mục lớn chứa toàn bộ dữ liệu của app
  static const String rootFolder = 'GDTM';

  // Các thư mục con
  static const String feedbackFolder =
      '$rootFolder/feedback_attachments';

  static const String conversationFolder =
      '$rootFolder/conversation_attachments';

  static const String announcementFolder =
      '$rootFolder/announcement_attachments';

  static const int maxFileBytes = 20 * 1024 * 1024;
  static const int maxTotalBytes = 40 * 1024 * 1024;
}

/// Lỗi upload có thông báo tiếng Việt, hiển thị thẳng cho người dùng.
class CloudinaryException implements Exception {
  final String message;
  const CloudinaryException(this.message);

  @override
  String toString() => message;
}

/// Kết quả Cloudinary trả về sau khi upload (kèm thông tin tệp gốc
/// để dựng FileAttachment mà không cần giữ lại PlatformFile).
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final String resourceType; // image | video | raw
  final int bytes;

  /// Tên tệp gốc người dùng chọn.
  final String fileName;

  /// Phần mở rộng viết thường, không có dấu chấm (pdf, docx, png...).
  final String fileType;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.resourceType,
    required this.bytes,
    required this.fileName,
    required this.fileType,
  });
}

class CloudinaryService {
  static const Duration _timeout = Duration(minutes: 3);

  /// Kiểm tra danh sách tệp trước khi upload.
  /// Trả về thông báo lỗi tiếng Việt, hoặc null nếu hợp lệ.
  static String? validateFiles(List<PlatformFile> files) {
    var total = 0;
    for (final f in files) {
      if (f.size > CloudinaryConfig.maxFileBytes) {
        return 'Tệp "${f.name}" vượt quá 20MB.';
      }
      total += f.size;
    }
    if (total > CloudinaryConfig.maxTotalBytes) {
      return 'Tổng dung lượng các tệp vượt quá 40MB.';
    }
    return null;
  }

  /// Upload một file lên Cloudinary.
  ///
  /// - [folder]: thư mục gốc, dùng các hằng `CloudinaryConfig.*Folder`.
  /// - [ownerId]: id của góp ý / hội thoại / thông báo; nếu có thì file
  ///   được xếp vào `folder/ownerId` cho dễ quản lý.
  ///
  /// Dùng endpoint `auto/upload` để Cloudinary tự nhận loại file
  /// (ảnh, pdf, docx, zip...). File phải được chọn với `withData: true`
  /// (để có `file.bytes`, chạy được cả Web lẫn Android/iOS).
  Future<CloudinaryUploadResult> uploadFile(
    PlatformFile file, {
    String folder = CloudinaryConfig.feedbackFolder,
    String? ownerId,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw CloudinaryException('Không đọc được nội dung tệp "${file.name}".');
    }

    final targetFolder =
        (ownerId == null || ownerId.isEmpty) ? folder : '$folder/$ownerId';

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/auto/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = targetFolder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      final body = _decode(response.body);

      if (response.statusCode != 200) {
        final detail = (body['error'] is Map)
            ? (body['error']['message'] ?? '').toString()
            : '';
        throw CloudinaryException(
          'Tải tệp "${file.name}" thất bại'
          '${detail.isNotEmpty ? ': $detail' : ' (${response.statusCode})'}.',
        );
      }

      final url = body['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw CloudinaryException(
          'Cloudinary không trả về đường dẫn cho tệp "${file.name}".',
        );
      }

      return CloudinaryUploadResult(
        secureUrl: url,
        publicId: (body['public_id'] ?? '').toString(),
        resourceType: (body['resource_type'] ?? 'raw').toString(),
        bytes: (body['bytes'] as num?)?.toInt() ?? file.size,
        fileName: file.name,
        fileType: _extensionOf(file.name),
      );
    } on TimeoutException {
      throw CloudinaryException(
        'Tải tệp "${file.name}" quá lâu. Vui lòng kiểm tra mạng và thử lại.',
      );
    } on CloudinaryException {
      rethrow;
    } catch (_) {
      throw CloudinaryException(
        'Không kết nối được Cloudinary khi tải "${file.name}".',
      );
    }
  }

  /// Upload nhiều file lần lượt, báo tiến độ qua [onProgress]
  /// (done = số tệp đã xong, total = tổng số tệp).
  /// Nếu một tệp lỗi thì dừng và ném [CloudinaryException].
  Future<List<CloudinaryUploadResult>> uploadFiles(
    List<PlatformFile> files, {
    String folder = CloudinaryConfig.feedbackFolder,
    String? ownerId,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <CloudinaryUploadResult>[];
    for (var i = 0; i < files.length; i++) {
      onProgress?.call(i, files.length);
      results.add(await uploadFile(files[i], folder: folder, ownerId: ownerId));
    }
    onProgress?.call(files.length, files.length);
    return results;
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}