import 'package:cloud_firestore/cloud_firestore.dart';

/// Kết quả sau khi ghi nhận một lần đăng nhập sai.
class LoginFailureResult {
  /// true nếu tài khoản đang bị khoá (vừa bị khoá hoặc đã bị khoá từ trước).
  final bool isLocked;

  /// Số lần thử còn lại trước khi bị khoá (0 nếu đang bị khoá).
  final int remainingAttempts;

  /// Thời gian khoá còn lại (Duration.zero nếu chưa bị khoá).
  final Duration lockRemaining;

  const LoginFailureResult({
    required this.isLocked,
    required this.remainingAttempts,
    required this.lockRemaining,
  });
}

/// Giới hạn số lần đăng nhập sai (rate limit) cho đăng nhập bằng
/// tài khoản + mật khẩu. KHÔNG áp dụng cho đăng nhập Google.
///
/// Trạng thái được lưu trên Firestore, collection [collection], mỗi tài khoản
/// một document:
///   login_attempts/{key} = {
///     failedCount : int        // số lần sai liên tiếp
///     lastFailedAt: Timestamp  // lần sai gần nhất
///     lockedUntil : Timestamp  // (chỉ có khi đang/đã bị khoá)
///   }
///
/// Nhờ lưu trên Firestore nên khoá có hiệu lực trên mọi thiết bị và không bị
/// reset khi người dùng thoát/mở lại app.
class LoginAttemptService {
  LoginAttemptService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Tên collection lưu trạng thái đăng nhập sai.
  static const String collection = 'login_attempts';

  /// Số lần sai liên tiếp tối đa. Sai đủ số này thì bị khoá.
  static const int maxFailedAttempts = 5;

  /// Thời gian khoá tạm thời.
  static const Duration lockDuration = Duration(minutes: 5);

  /// Nếu lần sai trước đã cách quá khoảng này thì đếm lại từ đầu
  /// (tránh cộng dồn các lần sai rải rác nhiều ngày).
  static const Duration attemptWindow = Duration(minutes: 15);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _ref(String key) =>
      _firestore.collection(collection).doc(key);

  /// Tạo document ID từ tên đăng nhập / ID tài khoản.
  /// - Chữ thường + encode để không chứa '/' (document ID không cho phép).
  /// - Cắt ngắn để không vượt giới hạn độ dài.
  static String keyFor(String raw) {
    final encoded = Uri.encodeComponent(raw.trim().toLowerCase());
    final cut = encoded.length > 200 ? encoded.substring(0, 200) : encoded;
    return 'acc_$cut';
  }

  /// Đổi thời gian còn lại thành chuỗi tiếng Việt, vd "4 phút 30 giây".
  static String formatRemaining(Duration d) {
    final totalSeconds = (d.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0 && seconds > 0) return '$minutes phút $seconds giây';
    if (minutes > 0) return '$minutes phút';
    return '${seconds <= 0 ? 1 : seconds} giây';
  }

  static DateTime? _toDate(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  /// Trả về thời gian khoá còn lại, hoặc null nếu KHÔNG bị khoá.
  Future<Duration?> getRemainingLock(String key) async {
    final snap = await _ref(key).get();
    if (!snap.exists) return null;

    final lockedUntil = _toDate(snap.data()?['lockedUntil']);
    if (lockedUntil == null) return null;

    final remaining = lockedUntil.difference(DateTime.now());
    return remaining > Duration.zero ? remaining : null;
  }

  /// Ghi nhận 1 lần đăng nhập sai (dùng transaction để tránh đếm sai khi
  /// nhiều request cùng lúc). Đủ [maxFailedAttempts] lần thì khoá [lockDuration].
  Future<LoginFailureResult> recordFailure(String key) {
    final ref = _ref(key);

    return _firestore.runTransaction<LoginFailureResult>((tx) async {
      final snap = await tx.get(ref);
      final now = DateTime.now();
      var count = 0;

      if (snap.exists) {
        final data = snap.data() ?? <String, dynamic>{};
        final lockedUntil = _toDate(data['lockedUntil']);
        final lastFailedAt = _toDate(data['lastFailedAt']);

        // Đang bị khoá (trường hợp 2 request đến cùng lúc).
        if (lockedUntil != null && lockedUntil.isAfter(now)) {
          return LoginFailureResult(
            isLocked: true,
            remainingAttempts: 0,
            lockRemaining: lockedUntil.difference(now),
          );
        }

        final lockExpired = lockedUntil != null; // có khoá nhưng đã hết hạn
        final windowExpired = lastFailedAt == null ||
            now.difference(lastFailedAt) > attemptWindow;

        // Hết khoá hoặc lần sai trước quá lâu -> đếm lại từ 0.
        if (!lockExpired && !windowExpired) {
          count = (data['failedCount'] as num?)?.toInt() ?? 0;
        }
      }

      count += 1;

      if (count >= maxFailedAttempts) {
        tx.set(ref, {
          'failedCount': count,
          'lastFailedAt': Timestamp.fromDate(now),
          'lockedUntil': Timestamp.fromDate(now.add(lockDuration)),
        });
        return const LoginFailureResult(
          isLocked: true,
          remainingAttempts: 0,
          lockRemaining: lockDuration,
        );
      }

      tx.set(ref, {
        'failedCount': count,
        'lastFailedAt': Timestamp.fromDate(now),
      });
      return LoginFailureResult(
        isLocked: false,
        remainingAttempts: maxFailedAttempts - count,
        lockRemaining: Duration.zero,
      );
    });
  }

  /// Xoá bộ đếm khi đăng nhập thành công.
  /// Lỗi ở bước này không được làm hỏng lần đăng nhập đã thành công.
  Future<void> reset(String key) async {
    try {
      await _ref(key).delete();
    } catch (_) {
      // bỏ qua
    }
  }
}
