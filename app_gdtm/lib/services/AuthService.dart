import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/enums/user_role.dart';

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
}
