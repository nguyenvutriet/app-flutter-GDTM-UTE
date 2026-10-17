import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/services/LoginAttemptService.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Chỉ cho phép email của trường (kiểm tra lại đúng tên miền thực tế của trường bạn):
const List<String> _allowedEmailDomains = [
  'student.hcmute.edu.vn',
  'hcmute.edu.vn',
  'teacher.hcmute.edu.vn',
];


/// Lỗi đăng nhập có thông báo tiếng Việt, hiển thị thẳng cho người dùng.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Kết quả đăng nhập thành công.
class AuthResult {
  final Users user;
  final UserRole role;
  const AuthResult({required this.user, required this.role});
}

class AuthService {
  /// Tên collection chứa tài khoản trên Firestore.
  /// TODO: nếu collection của bạn tên khác (vd: 'user', 'Users') thì sửa ở đây.
  static const String usersCollection = 'users';

  /// Thông báo chung cho cả "sai tên đăng nhập" và "sai mật khẩu"
  /// (không cho biết cái nào sai để tránh dò tài khoản).
  static const String _invalidCredentials =
      'Tên đăng nhập hoặc mật khẩu không đúng.';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Giới hạn số lần đăng nhập sai (chỉ dùng cho đăng nhập tài khoản + mật khẩu).
  final LoginAttemptService _loginAttempts = LoginAttemptService();

  /// Đăng nhập bằng tên đăng nhập (mã số / email) + mật khẩu.
  /// Ném [AuthException] nếu thất bại.
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final input = username.trim();
      final doc = await _findUserDoc(input);

      // Khoá đếm theo tài khoản (doc.id) để nhập bằng mã số hay email đều
      // dùng chung 1 bộ đếm. Tài khoản không tồn tại vẫn được đếm theo chuỗi
      // đã nhập, để thông báo giống hệt (không lộ tài khoản nào có thật).
      final attemptKey = LoginAttemptService.keyFor(doc?.id ?? input);

      // 1. Đang bị khoá -> từ chối ngay, không kiểm tra mật khẩu.
      final lockRemaining = await _loginAttempts.getRemainingLock(attemptKey);
      if (lockRemaining != null) {
        throw AuthException(_lockedMessage(lockRemaining));
      }

      // 2. Sai tài khoản hoặc mật khẩu -> ghi nhận 1 lần sai.
      final user = doc == null ? null : Users.fromFirestore(doc);
      if (user == null || !_passwordMatches(password, user.password)) {
        final failure = await _loginAttempts.recordFailure(attemptKey);
        if (failure.isLocked) {
          throw AuthException(_lockedMessage(failure.lockRemaining));
        }
        throw AuthException(
          '$_invalidCredentials Bạn còn ${failure.remainingAttempts} lần thử.',
        );
      }

      // 3. Đúng mật khẩu -> xoá bộ đếm sai.
      await _loginAttempts.reset(attemptKey);

      final role = UserRoleX.fromString(user.role);
      if (role == null) {
        throw const AuthException(
          'Tài khoản chưa được phân quyền hợp lệ. Vui lòng liên hệ quản trị viên.',
        );
      }

      return AuthResult(user: user, role: role);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'Không có quyền đọc/ghi dữ liệu đăng nhập (users, login_attempts). Hãy kiểm tra Firestore Rules.',
        );
      }
      if (e.code == 'unavailable') {
        throw const AuthException(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.',
        );
      }
      throw AuthException('Lỗi hệ thống (${e.code}). Vui lòng thử lại.');
    }

    

  }

  /// Thông báo khi tài khoản đang bị khoá do nhập sai quá nhiều lần.
  String _lockedMessage(Duration remaining) =>
      'Bạn đã nhập sai quá ${LoginAttemptService.maxFailedAttempts} lần. '
      'Vui lòng thử lại sau ${LoginAttemptService.formatRemaining(remaining)}.';

  /// Tìm tài khoản theo thứ tự:
  ///   1. Document ID == username
  ///   2. Field `id`    == username
  ///   3. Field `email` == username
  Future<DocumentSnapshot?> _findUserDoc(String username) async {
    final users = _firestore.collection(usersCollection);

    // Document ID không được chứa '/'
    if (!username.contains('/')) {
      final byDocId = await users.doc(username).get();
      if (byDocId.exists) return byDocId;
    }

    for (final field in const ['id', 'email']) {
      final query =
          await users.where(field, isEqualTo: username).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first;
    }
    return null;
  }

  /// - Mật khẩu dạng BCrypt (bắt đầu bằng "$2"): so sánh bằng BCrypt.
  /// - Ngược lại: so sánh chuỗi thường.
  ///
  /// TODO(bảo mật): nên chuyển hẳn sang mật khẩu băm hoặc Firebase Authentication,
  /// xem mục "Bảo mật" trong HUONG_DAN_CAI_DAT.md.
  bool _passwordMatches(String input, String? stored) {
    if (stored == null || stored.isEmpty) return false;
    if (stored.startsWith(r'$2')) {
      try {
        return BCrypt.checkpw(input, stored);
      } catch (_) {
        return false;
      }
    }
    return input == stored;
  }

  // ============================================================
  // ĐĂNG NHẬP GOOGLE
  // ============================================================

  /// Dọn sạch MỌI phiên đăng nhập còn sót (Google + Firebase).
  /// Từng bước được bọc try/catch riêng: một bước lỗi KHÔNG được làm hỏng
  /// các bước còn lại, và hàm này không bao giờ ném lỗi ra ngoài.
  Future<void> _clearSession() async {
    // Trên web, GoogleSignIn chưa được initialize nên không được gọi
    if (!kIsWeb) {
      try {
        // Android: xoá credential state -> lần sau luôn hiện hộp chọn tài khoản
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Đăng xuất hoàn toàn (gọi khi người dùng bấm "Đăng xuất").
  Future<void> signOut() => _clearSession();

  Future<AuthResult> signInWithGoogle() async {
    // Chỉ true khi đã đi hết luồng và trả về kết quả thành công.
    // Mọi trường hợp còn lại (lỗi, huỷ, sai email...) -> khối finally sẽ dọn phiên.
    bool success = false;

    try {
      // (1) FIX: dọn phiên cũ TRƯỚC khi đăng nhập, để lần thử sau
      // không bị dính trạng thái của lần thử trước (đăng nhập sai / đã đăng nhập).
      await _clearSession();

      String? email;

      if (kIsWeb) {
        // WEB: popup của Firebase Auth
        final provider = GoogleAuthProvider();
        // (2) FIX: luôn hiện hộp chọn tài khoản, không tự dùng tài khoản đã nhớ
        provider.setCustomParameters({'prompt': 'select_account'});
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        email = cred.user?.email?.toLowerCase();
      } else {
        // ANDROID / iOS: google_sign_in v7
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw const AuthException('Không lấy được thông tin từ Google.');
        }
        final cred = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
        email = cred.user?.email?.toLowerCase();
      }

      if (email == null) {
        throw const AuthException('Tài khoản Google không có email.');
      }

      // Chỉ cho phép email của trường
      final domain = email.split('@').last;
      if (!_allowedEmailDomains.contains(domain)) {
        throw const AuthException('Vui lòng dùng email của trường để đăng nhập.');
      }

      // Tìm user trong Firestore theo email để lấy role
      final query = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        throw AuthException('Email $email chưa được cấp tài khoản trong hệ thống.');
      }

      final user = Users.fromFirestore(query.docs.first);
      final role = UserRoleX.fromString(user.role);
      if (role == null) {
        throw const AuthException(
          'Tài khoản chưa được phân quyền hợp lệ. Vui lòng liên hệ quản trị viên.',
        );
      }

      success = true;
      return AuthResult(user: user, role: role);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Bạn đã huỷ đăng nhập Google.');
      }
      throw AuthException('Đăng nhập Google thất bại (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw const AuthException('Bạn đã huỷ đăng nhập Google.');
      }
      if (e.code == 'popup-blocked') {
        throw const AuthException(
          'Trình duyệt đã chặn cửa sổ đăng nhập. Hãy cho phép popup rồi thử lại.',
        );
      }
      throw AuthException('Đăng nhập Firebase thất bại (${e.code}).');
    } on FirebaseException catch (e) {
      // (3) FIX: lỗi Firestore (permission-denied, unavailable...) trước đây
      // KHÔNG được bắt ở đây nên phiên Google/Firebase bị giữ lại.
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'Không có quyền đọc dữ liệu tài khoản. Hãy kiểm tra Firestore Rules.',
        );
      }
      if (e.code == 'unavailable') {
        throw const AuthException(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.',
        );
      }
      throw AuthException('Lỗi hệ thống (${e.code}). Vui lòng thử lại.');
    } finally {
      // (4) FIX: đảm bảo LUÔN dọn phiên khi thất bại, bất kể lỗi thuộc loại nào.
      if (!success) {
        await _clearSession();
      }
    }
  }
}
