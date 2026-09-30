import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/enums/user_role.dart';
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

  /// Đăng nhập bằng tên đăng nhập (mã số / email) + mật khẩu.
  /// Ném [AuthException] nếu thất bại.
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final doc = await _findUserDoc(username.trim());
      if (doc == null) throw const AuthException(_invalidCredentials);

      final user = Users.fromFirestore(doc);
      if (!_passwordMatches(password, user.password)) {
        throw const AuthException(_invalidCredentials);
      }

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
          'Không có quyền đọc dữ liệu tài khoản. Hãy kiểm tra Firestore Rules.',
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

  // TODO(google-signin): thêm signInWithGoogle() theo HUONG_DAN_GOOGLE_SIGN_IN.md
  Future<AuthResult> signInWithGoogle() async {
  try {
    String? email;

    if (kIsWeb) {
      // WEB: popup của Firebase Auth
      final cred =
          await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
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
      await signOut();
      throw const AuthException('Tài khoản Google không có email.');
    }

    // (Tuỳ chọn) chỉ cho phép email của trường
    final domain = email.split('@').last;
    if (!_allowedEmailDomains.contains(domain)) {
      await signOut();
      throw const AuthException('Vui lòng dùng email của trường để đăng nhập.');
    }

    // Tìm user trong Firestore theo email để lấy role
    final query = await _firestore
        .collection(usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      await signOut();
      throw AuthException('Email $email chưa được cấp tài khoản trong hệ thống.');
    }

    final user = Users.fromFirestore(query.docs.first);
    final role = UserRoleX.fromString(user.role);
    if (role == null) {
      await signOut();
      throw const AuthException(
        'Tài khoản chưa được phân quyền hợp lệ. Vui lòng liên hệ quản trị viên.',
      );
    }
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
  }
}

Future<void> signOut() async {
  // Trên web, GoogleSignIn chưa được initialize nên không được gọi
  if (!kIsWeb) {
    await GoogleSignIn.instance.signOut();
  }
  await FirebaseAuth.instance.signOut();
}
}
