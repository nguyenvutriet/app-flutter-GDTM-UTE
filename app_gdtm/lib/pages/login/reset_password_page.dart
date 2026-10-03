import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/pages/login/auth_layout.dart';
import 'package:app_gdtm/services/PasswordResetService.dart';

/// Trang "ĐẶT LẠI MẬT KHẨU" (bước cuối, sau khi nhập đúng OTP).
///
/// - 2 ô: mật khẩu mới + nhập lại mật khẩu mới (có nút hiện/ẩn mật khẩu).
/// - Bấm "Thay đổi mật khẩu": kiểm tra ràng buộc -> băm bcrypt -> cập nhật
///   field `password` của user trên Firestore ([PasswordResetService.resetPassword])
///   -> báo thành công và quay về form đăng nhập.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.session});

  final PasswordResetSession session;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const int _minLength = PasswordResetService.passwordMinLength;
  static const int _maxLength = PasswordResetService.passwordMaxLength;

  // Chỉ nhận ký tự ASCII hiển thị được (không dấu cách, không chữ có dấu).
  static final RegExp _invalidChar = RegExp(r'[^\x21-\x7E]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[^A-Za-z0-9]');

  final _formKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _service = PasswordResetService();

  // Chỉ báo lỗi sau lần bấm nút đầu tiên; từ đó lỗi cập nhật theo lúc gõ.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  /// Lỗi trả về từ hệ thống (trùng mật khẩu cũ, phiên hết hạn, mất mạng...).
  String? _errorMessage;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATE
  // ============================================================

  String? _validateNewPassword(String? value) {
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
    if (pw.toLowerCase().contains(widget.session.studentId.toLowerCase())) {
      return 'Mật khẩu không được chứa mã SV/HV/NCS';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Vui lòng nhập lại mật khẩu mới';
    if (confirm != _newCtrl.text) return 'Mật khẩu nhập lại không khớp';
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
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      // Đưa con trỏ về ô lỗi đầu tiên.
      if (_validateNewPassword(_newCtrl.text) != null) {
        _newFocus.requestFocus();
      } else {
        _confirmFocus.requestFocus();
      }
      return;
    }

    setState(() => _loading = true);
    var success = false;
    try {
      await _service.resetPassword(widget.session, _newCtrl.text);
      success = true;
      if (!mounted) return;
      _finishAndGoToLogin();
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      // Thành công thì giữ nguyên trạng thái "đang xử lý" cho tới khi trang đóng.
      if (mounted && !success) setState(() => _loading = false);
    }
  }

  /// Báo thành công rồi quay về form đăng nhập (trang đầu tiên của stack).
  /// SnackBar thuộc ScaffoldMessenger của cả app nên vẫn hiện sau khi chuyển trang.
  void _finishAndGoToLogin() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          backgroundColor: kAuthSuccessColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thay đổi mật khẩu thành công. '
                  'Hãy đăng nhập bằng mật khẩu mới.',
                ),
              ),
            ],
          ),
        ),
      );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Quay về form đăng nhập (bỏ qua việc đặt lại mật khẩu).
  void _backToLogin() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Gõ lại thì xoá lỗi hệ thống cũ (lỗi validate tự cập nhật theo Form).
  void _clearServerError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Đang lưu mật khẩu thì chặn nút Back để tránh bỏ dở giữa chừng.
    return PopScope(
      canPop: !_loading,
      child: AuthPageLayout(
        heading: 'ĐẶT LẠI MẬT KHẨU',
        footerLabel: 'Đăng nhập',
        onFooterTap: _loading ? null : _backToLogin,
        body: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: kAuthMutedColor,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Nhập mật khẩu mới cho tài khoản '),
                    TextSpan(
                      text: widget.session.studentId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kAuthTitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mật khẩu mới
              TextFormField(
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
                  _clearServerError();
                  // Đổi mật khẩu mới thì kiểm tra lại ô nhập lại (nếu đã gõ).
                  if (_confirmCtrl.text.isNotEmpty) {
                    _confirmKey.currentState?.validate();
                  }
                },
                onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                decoration: authInputDecoration(
                  'Mật khẩu mới',
                  suffixIcon: _visibilityButton(
                    obscure: _obscureNew,
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: _validateNewPassword,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 2),
                child: Text(
                  'Từ $_minLength đến $_maxLength ký tự, gồm chữ hoa, chữ thường, '
                  'chữ số và ký tự đặc biệt.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: kAuthMutedColor,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nhập lại mật khẩu mới
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
                onChanged: (_) => _clearServerError(),
                onFieldSubmitted: (_) => _onSubmit(),
                decoration: authInputDecoration(
                  'Nhập lại mật khẩu mới',
                  suffixIcon: _visibilityButton(
                    obscure: _obscureConfirm,
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: _validateConfirm,
              ),

              // Lỗi từ hệ thống
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                AuthErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 24),

              AuthPrimaryButton(
                label: 'Thay đổi mật khẩu',
                loading: _loading,
                onPressed: _onSubmit,
              ),
            ],
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
        color: kAuthMutedColor,
      ),
      onPressed: _loading ? null : onPressed,
    );
  }
}
