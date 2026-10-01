import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import 'package:app_gdtm/services/AuthService.dart';

/// Cấu hình EmailJS (dịch vụ gửi email gọi trực tiếp từ app qua HTTP).
///
/// Chỉ đặt ở đây Service ID, Template ID và Public Key (an toàn để đưa vào app,
/// giống cách cấu hình Cloudinary). TUYỆT ĐỐI KHÔNG đưa Private Key vào app.
/// Cách lấy 3 giá trị này: xem HUONG_DAN_QUEN_MAT_KHAU.md.
class EmailJsConfig {
  static const String serviceId = 'service_bsh3bg9';
  static const String templateId = 'template_su5van9';
  static const String publicKey = 'Uwgwb8uXov93_vwBv';

  static const String endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  static bool get isConfigured =>
      !serviceId.startsWith('YOUR_') &&
      !templateId.startsWith('YOUR_') &&
      !publicKey.startsWith('YOUR_');
}

/// Lỗi quên mật khẩu có thông báo tiếng Việt, hiển thị thẳng cho người dùng.
class PasswordResetException implements Exception {
  final String message;
  const PasswordResetException(this.message);

  @override
  String toString() => message;
}

/// Loại lỗi khi kiểm tra mã OTP.
enum OtpError {
  /// Mã đã quá thời gian hiệu lực.
  expired,

  /// Nhập sai mã (vẫn còn lượt thử).
  wrong,

  /// Sai quá số lần cho phép -> mã bị huỷ, phải gửi lại mã mới.
  tooManyAttempts,
}

class OtpVerifyException extends PasswordResetException {
  final OtpError error;
  const OtpVerifyException(this.error, super.message);
}

/// Một phiên đặt lại mật khẩu: lưu tài khoản đã xác thực + mã OTP hiện tại.
///
/// OTP chỉ nằm trong bộ nhớ của app (không ghi ra Firestore, không ghi log).
class PasswordResetSession {
  PasswordResetSession._({
    required this.userDocId,
    required this.studentId,
    required this.email,
    required this.fullName,
    required String otp,
    required DateTime expiresAt,
  })  : _otp = otp,
        _expiresAt = expiresAt;

  /// ID document của user trong collection `users` (dùng cho bước đổi mật khẩu).
  final String userDocId;
  final String studentId;

  /// Email đã đăng ký của tài khoản (lấy từ Firestore).
  final String email;
  final String fullName;

  String _otp;
  DateTime _expiresAt;
  int _failedAttempts = 0;
  bool _verified = false;

  /// Đã nhập đúng OTP.
  bool get isVerified => _verified;

  /// Thời gian còn lại của mã OTP hiện tại (0 nếu đã hết hạn / bị huỷ).
  Duration get remaining {
    if (_otp.isEmpty) return Duration.zero;
    final d = _expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Email che bớt, vd: "ab***@gmail.com".
  String get maskedEmail {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final visible = local.length <= 2 ? 1 : 2;
    return '${local.substring(0, visible)}***${email.substring(at)}';
  }
}

class PasswordResetService {
  /// Thời gian hiệu lực của mã OTP: 1 phút 30 giây.
  static const Duration otpLifetime = Duration(seconds: 90);

  /// Số lần nhập sai tối đa trước khi mã bị huỷ.
  static const int maxAttempts = 5;

  static const Duration _networkTimeout = Duration(seconds: 20);

  /// Dùng chung cho "không có tài khoản" và "sai email" để không lộ thông tin
  /// tài khoản nào tồn tại (cùng tinh thần với thông báo ở màn đăng nhập).
  static const String _accountMismatch =
      'Mã SV/HV/NCS không tồn tại hoặc email không khớp với email đã đăng ký.';

  static const String _networkError =
      'Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // BƯỚC 1: KIỂM TRA TÀI KHOẢN + GỬI OTP
  // ============================================================

  /// Kiểm tra [studentId] có tồn tại trên Firestore và [email] có đúng là
  /// email của tài khoản đó không. Nếu đúng: sinh OTP 6 số, gửi vào email,
  /// trả về [PasswordResetSession]. Ném [PasswordResetException] nếu thất bại.
  Future<PasswordResetSession> requestReset({
    required String studentId,
    required String email,
  }) async {
    final id = studentId.trim();
    final inputEmail = email.trim().toLowerCase();

    DocumentSnapshot? doc;
    try {
      doc = await _findUserDoc(id).timeout(_networkTimeout);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    } on TimeoutException {
      throw const PasswordResetException(_networkError);
    }

    if (doc == null) throw const PasswordResetException(_accountMismatch);

    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final storedEmail = ((data['email'] as String?) ?? '').trim();
    if (storedEmail.isEmpty) {
      throw const PasswordResetException(
        'Tài khoản chưa có email đăng ký. Vui lòng liên hệ quản trị viên.',
      );
    }
    if (storedEmail.toLowerCase() != inputEmail) {
      throw const PasswordResetException(_accountMismatch);
    }

    final fullName = ((data['fullName'] as String?) ?? '').trim();
    final displayName = fullName.isEmpty ? id : fullName;

    final otp = generateOtp();
    await _sendOtpEmail(
      toEmail: storedEmail,
      toName: displayName,
      studentId: id,
      otp: otp,
    );

    return PasswordResetSession._(
      userDocId: doc.id,
      studentId: id,
      email: storedEmail,
      fullName: displayName,
      otp: otp,
      expiresAt: DateTime.now().add(otpLifetime),
    );
  }

  // ============================================================
  // BƯỚC 2: GỬI LẠI MÃ
  // ============================================================

  /// Sinh OTP mới, gửi lại vào email, đặt lại thời gian hiệu lực và số lần thử.
  /// Nếu gửi thất bại thì mã cũ giữ nguyên.
  Future<void> resendOtp(PasswordResetSession session) async {
    final otp = generateOtp();
    await _sendOtpEmail(
      toEmail: session.email,
      toName: session.fullName,
      studentId: session.studentId,
      otp: otp,
    );
    session._otp = otp;
    session._expiresAt = DateTime.now().add(otpLifetime);
    session._failedAttempts = 0;
  }

  // ============================================================
  // BƯỚC 3: KIỂM TRA MÃ OTP
  // ============================================================

  /// Kiểm tra mã người dùng nhập. Đúng thì trả về bình thường (và đánh dấu
  /// session đã xác thực), sai thì ném [OtpVerifyException].
  void verifyOtp(PasswordResetSession session, String input) {
    if (session._verified) return;

    if (session._otp.isEmpty) {
      throw const OtpVerifyException(
        OtpError.tooManyAttempts,
        'Mã OTP không còn hiệu lực. Vui lòng gửi lại mã.',
      );
    }
    if (session.remaining == Duration.zero) {
      throw const OtpVerifyException(
        OtpError.expired,
        'Mã OTP đã hết hạn. Vui lòng gửi lại mã.',
      );
    }

    if (input.trim() != session._otp) {
      session._failedAttempts++;
      final left = maxAttempts - session._failedAttempts;
      if (left <= 0) {
        session._otp = ''; // huỷ mã, bắt buộc gửi lại
        throw OtpVerifyException(
          OtpError.tooManyAttempts,
          'Bạn đã nhập sai quá $maxAttempts lần. Vui lòng gửi lại mã.',
        );
      }
      throw OtpVerifyException(
        OtpError.wrong,
        'Mã OTP không chính xác. Bạn còn $left lần thử.',
      );
    }

    session._otp = ''; // mã chỉ dùng được một lần
    session._verified = true;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// 6 chữ số ngẫu nhiên (000000 – 999999), dùng bộ sinh số an toàn.
  static String generateOtp() {
    return Random.secure().nextInt(1000000).toString().padLeft(6, '0');
  }

  /// Tìm user theo thứ tự: Document ID == mã, rồi field `id` == mã
  /// (giống cách AuthService tìm khi đăng nhập).
  Future<DocumentSnapshot?> _findUserDoc(String studentId) async {
    final users = _firestore.collection(AuthService.usersCollection);

    // Document ID không được chứa '/'
    if (!studentId.contains('/')) {
      final byDocId = await users.doc(studentId).get();
      if (byDocId.exists) return byDocId;
    }

    final query =
        await users.where('id', isEqualTo: studentId).limit(1).get();
    return query.docs.isEmpty ? null : query.docs.first;
  }

  PasswordResetException _mapFirestoreError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return const PasswordResetException(
        'Không có quyền đọc dữ liệu tài khoản. Hãy kiểm tra Firestore Rules.',
      );
    }
    if (e.code == 'unavailable') {
      return const PasswordResetException(_networkError);
    }
    return PasswordResetException('Lỗi hệ thống (${e.code}). Vui lòng thử lại.');
  }

  static String get _lifetimeText {
    final minutes = otpLifetime.inMinutes;
    final seconds = otpLifetime.inSeconds % 60;
    if (minutes > 0 && seconds > 0) return '$minutes phút $seconds giây';
    if (minutes > 0) return '$minutes phút';
    return '$seconds giây';
  }

  /// Gửi email chứa OTP qua EmailJS.
  /// Các biến template: to_email, to_name, student_id, otp_code, expire_text.
  Future<void> _sendOtpEmail({
    required String toEmail,
    required String toName,
    required String studentId,
    required String otp,
  }) async {
    if (!EmailJsConfig.isConfigured) {
      throw const PasswordResetException(
        'Chưa cấu hình dịch vụ gửi email. Hãy điền EmailJsConfig '
        '(xem HUONG_DAN_QUEN_MAT_KHAU.md).',
      );
    }

    try {
      final res = await http
          .post(
            Uri.parse(EmailJsConfig.endpoint),
            headers: {
              'Content-Type': 'application/json',
              // EmailJS yêu cầu có Origin khi gọi từ app (không phải trình duyệt).
              // Trên web, trình duyệt tự gắn Origin nên không đặt tay.
              if (!kIsWeb) 'origin': 'http://localhost',
            },
            body: jsonEncode({
              'service_id': EmailJsConfig.serviceId,
              'template_id': EmailJsConfig.templateId,
              'user_id': EmailJsConfig.publicKey,
              'template_params': {
                'to_email': toEmail,
                'to_name': toName,
                'student_id': studentId,
                'otp_code': otp,
                'expire_text': _lifetimeText,
              },
            }),
          )
          .timeout(_networkTimeout);

      if (res.statusCode == 200) return;

      // Chi tiết lỗi chỉ in ra console để dev xem, không hiện cho người dùng.
      debugPrint('EmailJS ${res.statusCode}: ${res.body}');
      if (res.statusCode == 429) {
        throw const PasswordResetException(
          'Gửi mã quá nhanh. Vui lòng đợi vài giây rồi thử lại.',
        );
      }
      throw PasswordResetException(
        'Không gửi được email (mã lỗi ${res.statusCode}). Vui lòng thử lại sau.',
      );
    } on TimeoutException {
      throw const PasswordResetException(_networkError);
    } on http.ClientException {
      throw const PasswordResetException(_networkError);
    }
  }
}
