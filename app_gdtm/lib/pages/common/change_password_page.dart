import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/services/ChangePasswordService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

// Màu riêng của trang (lấy theo form "Đặt lại mật khẩu").
const Color _mutedColor = Color(0xFF6B7A90);
const Color _fieldBorder = Color(0xFF9FB1CB);
const Color _cardBorder = Color(0xFFDCDCDC);
const Color _errorColor = Color(0xFFE53935);
const Color _successColor = Color(0xFF2E7D32);

/// Trang "ĐỔI MẬT KHẨU" dùng chung cho cả 3 role (sinh viên, giảng viên, admin).
///
/// Được nhúng vào vùng nội dung của AppShell (DashboardPage) khi bấm menu
/// "Đổi mật khẩu" (id: `change_password`), nên KHÔNG tự vẽ header/menu.
///
/// Quy trình:
///   1. Hiện biểu mẫu 3 ô: mật khẩu hiện tại, mật khẩu mới, xác nhận mật khẩu mới.
///   2. Bấm "Xác nhận": kiểm tra ràng buộc -> [ChangePasswordService] kiểm tra
///      mật khẩu hiện tại, băm BCrypt mật khẩu mới và cập nhật lên Firestore.
///   3. Thành công: hiện thông báo rồi gọi [onSuccess] để DashboardPage quay về
///      trang chủ của role.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    required this.user,
    required this.onSuccess,
  });

  /// Người dùng đang đăng nhập (widget.user của DashboardPage).
  final Users user;

  /// Gọi sau khi đổi mật khẩu thành công (DashboardPage chuyển về trang chủ).
  final VoidCallback onSuccess;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const int _minLength = ChangePasswordService.passwordMinLength;
  static const int _maxLength = ChangePasswordService.passwordMaxLength;

  // Chỉ nhận ký tự ASCII hiển thị được (không dấu cách, không chữ có dấu).
  static final RegExp _invalidChar = RegExp(r'[^\x21-\x7E]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[^A-Za-z0-9]');

  final _formKey = GlobalKey<FormState>();
  final _newKey = GlobalKey<FormFieldState<String>>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  final _service = ChangePasswordService();

  // Chỉ báo lỗi sau lần bấm nút đầu tiên; từ đó lỗi cập nhật theo lúc gõ.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  /// Lỗi "sai mật khẩu hiện tại" trả về từ hệ thống, hiện ngay dưới ô đó.
  String? _currentServerError;

  /// Lỗi chung từ hệ thống (mất mạng, không có quyền ghi, phiên hết hạn...).
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATE
  // ============================================================

  String? _validateCurrent(String? value) {
    if (_currentServerError != null) return _currentServerError;
    if ((value ?? '').isEmpty) return 'Mật khẩu hiện tại là bắt buộc';
    return null;
  }

  String? _validateNew(String? value) {
    final pw = value ?? '';
    if (pw.isEmpty) return 'Mật khẩu mới là bắt buộc';
    if (pw.length < _minLength) {
      return 'Mật khẩu phải có ít nhất $_minLength ký tự';
    }
    if (pw.length > _maxLength) {
      return 'Mật khẩu tối đa $_maxLength ký tự';
    }
    if (_invalidChar.hasMatch(pw)) {
      return 'Mật khẩu không được chứa dấu cách hoặc chữ có dấu';
    }
    if (!_lower.hasMatch(pw)) return 'Mật khẩu phải có ít nhất 1 chữ thường';
    if (!_upper.hasMatch(pw)) return 'Mật khẩu phải có ít nhất 1 chữ hoa';
    if (!_digit.hasMatch(pw)) return 'Mật khẩu phải có ít nhất 1 chữ số';
    if (!_special.hasMatch(pw)) {
      return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt (vd: @ # ! \$ %)';
    }
    final id = (widget.user.id ?? '').trim();
    if (id.isNotEmpty && pw.toLowerCase().contains(id.toLowerCase())) {
      return 'Mật khẩu không được chứa mã đăng nhập của bạn';
    }
    if (pw == _currentCtrl.text) {
      return 'Mật khẩu mới phải khác mật khẩu hiện tại';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Vui lòng xác nhận mật khẩu mới';
    if (confirm != _newCtrl.text) return 'Mật khẩu xác nhận không khớp';
    return null;
  }

  // ============================================================
  // LOGIC
  // ============================================================

  Future<void> _onSubmit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _errorMessage = null;
      _currentServerError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      // Đưa con trỏ về ô lỗi đầu tiên.
      if (_validateCurrent(_currentCtrl.text) != null) {
        _currentFocus.requestFocus();
      } else if (_validateNew(_newCtrl.text) != null) {
        _newFocus.requestFocus();
      } else {
        _confirmFocus.requestFocus();
      }
      return;
    }

    setState(() => _loading = true);
    var success = false;
    try {
      await _service.changePassword(
        user: widget.user,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      success = true;
      if (!mounted) return;
      _finish();
    } on WrongCurrentPasswordException catch (e) {
      if (!mounted) return;
      // Hiện lỗi ngay dưới ô "Mật khẩu hiện tại": mở khoá các ô trước, rồi mới
      // chạy lại validate (validator trả về _currentServerError).
      setState(() {
        _loading = false;
        _currentServerError = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formKey.currentState?.validate();
        _currentFocus.requestFocus();
      });
    } on ChangePasswordException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      // Thành công thì giữ trạng thái "đang xử lý" tới khi trang được thay thế.
      if (mounted && !success) setState(() => _loading = false);
    }
  }

  /// Báo thành công rồi quay về trang chủ của role.
  /// SnackBar thuộc ScaffoldMessenger của cả app nên vẫn hiện sau khi đổi trang.
  void _finish() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Đổi mật khẩu thành công.')),
            ],
          ),
        ),
      );
    widget.onSuccess();
  }

  /// Gõ lại thì xoá lỗi hệ thống cũ (lỗi validate tự cập nhật theo Form).
  void _clearServerErrors() {
    if (_errorMessage != null || _currentServerError != null) {
      setState(() {
        _errorMessage = null;
        _currentServerError = null;
      });
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final pad = narrow ? 20.0 : 32.0;

    // Đang lưu mật khẩu thì chặn nút Back để tránh bỏ dở giữa chừng.
    return PopScope(
      canPop: !_loading,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 552),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _cardBorder),
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐỔI MẬT KHẨU',
                      style: TextStyle(
                        fontSize: narrow ? 26 : 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cổng thông tin đào tạo',
                      style: TextStyle(fontSize: 14, color: _mutedColor),
                    ),
                    const SizedBox(height: 28),

                    // Mật khẩu hiện tại
                    TextFormField(
                      controller: _currentCtrl,
                      focusNode: _currentFocus,
                      enabled: !_loading,
                      obscureText: _obscureCurrent,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(128),
                      ],
                      onChanged: (_) {
                        _clearServerErrors();
                        // "Khác mật khẩu hiện tại" phụ thuộc ô này.
                        if (_newCtrl.text.isNotEmpty) {
                          _newKey.currentState?.validate();
                        }
                      },
                      onFieldSubmitted: (_) => _newFocus.requestFocus(),
                      decoration: _inputDecoration(
                        'Mật khẩu hiện tại',
                        suffixIcon: _visibilityButton(
                          obscure: _obscureCurrent,
                          onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                        ),
                      ),
                      validator: _validateCurrent,
                    ),
                    const SizedBox(height: 20),

                    // Mật khẩu mới
                    TextFormField(
                      key: _newKey,
                      controller: _newCtrl,
                      focusNode: _newFocus,
                      enabled: !_loading,
                      obscureText: _obscureNew,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(_maxLength),
                      ],
                      onChanged: (_) {
                        _clearServerErrors();
                        // Đổi mật khẩu mới thì kiểm tra lại ô xác nhận.
                        if (_confirmCtrl.text.isNotEmpty) {
                          _confirmKey.currentState?.validate();
                        }
                      },
                      onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                      decoration: _inputDecoration(
                        'Mật khẩu mới',
                        suffixIcon: _visibilityButton(
                          obscure: _obscureNew,
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: _validateNew,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8, left: 2),
                      child: Text(
                        'Từ $_minLength đến $_maxLength ký tự, gồm chữ hoa, '
                        'chữ thường, chữ số và ký tự đặc biệt.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _mutedColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Xác nhận mật khẩu mới
                    TextFormField(
                      key: _confirmKey,
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      enabled: !_loading,
                      obscureText: _obscureConfirm,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(_maxLength),
                      ],
                      onChanged: (_) => _clearServerErrors(),
                      onFieldSubmitted: (_) => _onSubmit(),
                      decoration: _inputDecoration(
                        'Xác nhận mật khẩu mới',
                        suffixIcon: _visibilityButton(
                          obscure: _obscureConfirm,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: _validateConfirm,
                    ),

                    // Lỗi chung từ hệ thống
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),

                    _PrimaryButton(
                      label: 'Xác nhận',
                      loading: _loading,
                      onPressed: _onSubmit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nút con mắt hiện / ẩn mật khẩu.
  Widget _visibilityButton({
    required bool obscure,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: _mutedColor,
      ),
      onPressed: _loading ? null : onPressed,
    );
  }

  /// Ô nhập nền trắng, viền xám xanh; khi lỗi: viền, label và dòng báo lỗi
  /// đều đỏ (giống form "Đặt lại mật khẩu").
  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    TextStyle labelStyle(Set<WidgetState> states, double size) {
      final isError = states.contains(WidgetState.error);
      return TextStyle(
        color: isError ? _errorColor : _mutedColor,
        fontSize: size,
      );
    }

    return InputDecoration(
      labelText: label,
      labelStyle: WidgetStateTextStyle.resolveWith((s) => labelStyle(s, 16)),
      floatingLabelStyle:
          WidgetStateTextStyle.resolveWith((s) => labelStyle(s, 14)),
      errorStyle: const TextStyle(color: _errorColor, fontSize: 12),
      errorMaxLines: 3,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      enabledBorder: border(_fieldBorder),
      disabledBorder: border(_fieldBorder),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(_errorColor),
      focusedErrorBorder: border(_errorColor, 2),
    );
  }
}

/// Nút xanh toàn chiều rộng; khi [loading] hiện vòng xoay và khoá nút.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Dòng báo lỗi (icon + chữ đỏ), dùng cho lỗi trả về từ hệ thống.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: _errorColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: _errorColor, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
