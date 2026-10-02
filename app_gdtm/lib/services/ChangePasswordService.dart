import 'dart:async';

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:app_gdtm/models/Users.dart';

// ============================================================
// BCRYPT (chạy trong isolate qua compute() để không treo giao diện)
// Phải là hàm top-level để compute() chạy được.
// ============================================================

/// Băm mật khẩu bằng BCrypt, vd: $2a$12$gbayR6kt.SIWiDMZZ.mKhOTE...
String _bcryptHash(String password) {
  return BCrypt.hashpw(
    password,
    BCrypt.gensalt(logRounds: ChangePasswordService.bcryptCost),
  );
}

/// args = [mật khẩu nhập vào, chuỗi hash đang lưu].
bool _bcryptCheck(List<String> args) {
  try {
    return BCrypt.checkpw(args[0], args[1]);
  } catch (_) {
    return false; // hash lưu sai định dạng -> coi như không khớp
  }
}

/// Lỗi đổi mật khẩu có thông báo tiếng Việt, hiển thị thẳng cho người dùng.
class ChangePasswordException implements Exception {
  final String message;
  const ChangePasswordException(this.message);

  @override
  String toString() => message;
}

/// Mật khẩu hiện tại nhập vào không đúng (trang hiển thị lỗi ngay dưới ô
/// "Mật khẩu hiện tại").
class WrongCurrentPasswordException extends ChangePasswordException {
  const WrongCurrentPasswordException()
      : super('Mật khẩu hiện tại không đúng');
}

/// Đổi mật khẩu cho người dùng đang đăng nhập (dùng chung cả 3 role).
///
/// Quy trình [changePassword]:
///   1. Tìm lại document của user trên Firestore (collection `users`).
///   2. Kiểm tra mật khẩu hiện tại với mật khẩu đang lưu
///      (BCrypt nếu bắt đầu bằng "$2", ngược lại so chuỗi thường - giống
///      cách AuthService đăng nhập).
///   3. Băm mật khẩu mới bằng BCrypt (cost 12 -> "$2a$12$...").
///   4. Cập nhật field `password` của document.
class ChangePasswordService {
  /// Tên collection chứa tài khoản (trùng với AuthService.usersCollection).
  static const String usersCollection = 'users';

  /// Độ khó BCrypt (log2 số vòng lặp): 12 -> hash dạng "$2a$12$...".
  /// Mỗi +1 là chậm gấp đôi; giảm xuống 10 nếu máy yếu thấy quá chậm.
  static const int bcryptCost = 12;

  /// Giới hạn độ dài mật khẩu mới (tối đa 64 ký tự ASCII, nằm trong giới hạn
  /// 72 byte của BCrypt).
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 64;

  static const Duration _timeout = Duration(seconds: 20);

  static const String _networkError =
      'Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Đổi mật khẩu của [user]. Thành công thì trả về bình thường (đồng thời
  /// cập nhật `user.password` trong bộ nhớ). Thất bại ném
  /// [ChangePasswordException] / [WrongCurrentPasswordException].
  Future<void> changePassword({
    required Users user,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // 1) Tìm document của user
      final snap = await _findUserDoc(user).timeout(_timeout);
      if (snap == null) {
        throw const ChangePasswordException(
          'Không tìm thấy tài khoản. Vui lòng đăng nhập lại.',
        );
      }

      // 2) Kiểm tra mật khẩu hiện tại (so với dữ liệu mới nhất trên Firestore)
      final stored = (snap.data()?['password'] as String?) ?? '';
      if (stored.isEmpty) {
        throw const ChangePasswordException(
          'Tài khoản chưa có mật khẩu. Hãy dùng chức năng "Quên mật khẩu" '
          'ở trang đăng nhập.',
        );
      }
      final correct = await _matches(currentPassword, stored);
      if (!correct) throw const WrongCurrentPasswordException();

      // Mật khẩu hiện tại đã đúng nên chỉ cần so với chuỗi người dùng nhập.
      if (newPassword == currentPassword) {
        throw const ChangePasswordException(
          'Mật khẩu mới phải khác mật khẩu hiện tại.',
        );
      }

      // 3) Băm BCrypt rồi 4) cập nhật lên Firestore
      final hashed = await compute(_bcryptHash, newPassword);
      await snap.reference.update({'password': hashed}).timeout(_timeout);

      user.password = hashed; // giữ dữ liệu trong bộ nhớ đồng bộ
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    } on TimeoutException {
      throw const ChangePasswordException(_networkError);
    }
  }

  /// Tìm document theo thứ tự (giống AuthService._findUserDoc):
  ///   1. Document ID == user.id
  ///   2. Field `id`    == user.id
  ///   3. Field `email` == user.email
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDoc(
    Users user,
  ) async {
    final users = _firestore.collection(usersCollection);

    final id = (user.id ?? '').trim();
    final email = (user.email ?? '').trim();
    if (id.isEmpty && email.isEmpty) {
      throw const ChangePasswordException(
        'Không xác định được tài khoản đang đăng nhập. '
        'Vui lòng đăng nhập lại.',
      );
    }

    if (id.isNotEmpty) {
      // Document ID không được chứa '/'
      if (!id.contains('/')) {
        final byDocId = await users.doc(id).get();
        if (byDocId.exists) return byDocId;
      }
      final byId = await users.where('id', isEqualTo: id).limit(1).get();
      if (byId.docs.isNotEmpty) return byId.docs.first;
    }

    if (email.isNotEmpty) {
      final byEmail =
          await users.where('email', isEqualTo: email).limit(1).get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first;
    }
    return null;
  }

  /// BCrypt (bắt đầu bằng "$2") hoặc chuỗi thường.
  Future<bool> _matches(String input, String stored) async {
    if (stored.startsWith(r'$2')) {
      return compute(_bcryptCheck, [input, stored]);
    }
    return input == stored;
  }

  ChangePasswordException _mapFirestoreError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return const ChangePasswordException(
        'Không có quyền cập nhật mật khẩu. Hãy kiểm tra Firestore Rules.',
      );
    }
    if (e.code == 'unavailable') {
      return const ChangePasswordException(_networkError);
    }
    return ChangePasswordException('Lỗi hệ thống (${e.code}). Vui lòng thử lại.');
  }
}
