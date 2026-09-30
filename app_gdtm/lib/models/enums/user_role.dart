enum UserRole { student, staff, admin }

/// Chuyển chuỗi role lưu trong Firestore (vd: "ROLE_ADMIN") sang [UserRole].
///
///   ROLE_ADMIN   -> UserRole.admin
///   ROLE_STUDENT -> UserRole.student
///   ROLE_TEACHER -> UserRole.staff   (giảng viên dùng chung giao diện "staff")
///   ROLE_STAFF   -> UserRole.staff   (chấp nhận thêm cho an toàn)
///
/// Không phân biệt hoa/thường, prefix "ROLE_" là tuỳ chọn.
/// Trả về null nếu role không hợp lệ.
extension UserRoleX on UserRole {
  static UserRole? fromString(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase().replaceFirst('ROLE_', '');
    switch (value) {
      case 'ADMIN':
        return UserRole.admin;
      case 'STUDENT':
        return UserRole.student;
      case 'TEACHER':
      case 'STAFF':
        return UserRole.staff;
      default:
        return null;
    }
  }
}
