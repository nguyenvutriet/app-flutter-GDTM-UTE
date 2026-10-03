import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/pages/login/auth_layout.dart';
import 'package:app_gdtm/pages/login/otp_verification_page.dart';
import 'package:app_gdtm/services/PasswordResetService.dart';

/// Trang "Quên mật khẩu" (chuyển từ giao diện web "Cổng thông tin đào tạo").
///
/// Luồng:
///   1. Nhập Mã SV/HV/NCS + email đã đăng ký, bấm "Gửi mã xác nhận".
///   2. Kiểm tra dữ liệu nhập (validate) -> kiểm tra tài khoản + email trên
///      Firestore -> gửi OTP 6 số vào email ([PasswordResetService]).
///   3. Thành công -> mở [OtpVerificationPage]; thất bại -> báo lỗi tại đây.
///
/// Nút "Đăng nhập" ở góc trái dưới card pop về form đăng nhập.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Giới hạn độ dài.
  static const int _idMinLength = 4;
  static const int _idMaxLength = 20;
  static const int _emailMaxLength = 254; // theo chuẩn RFC 5321
  static const int _emailLocalMaxLength = 64;

  // Mã SV/HV/NCS: chỉ gồm chữ cái (không dấu) và chữ số.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9]+$');

  // Email: phần tên + @ + tên miền có ít nhất một dấu chấm (vd: ute.edu.vn).
  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
    r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _service = PasswordResetService();

  // Chỉ báo lỗi sau lần bấm nút đầu tiên; từ đó lỗi cập nhật theo lúc gõ.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool _loading = false;

  /// Lỗi trả về từ hệ thống (tài khoản/email sai, mất mạng, gửi mail lỗi...).
  String? _errorMessage;

  @override
  void dispose() {
    _idCtrl.dispose();
    _emailCtrl.dispose();
    _idFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATE
  // ============================================================

  String? _validateStudentId(String? value) {
    final id = (value ?? '').trim();
    if (id.isEmpty) return 'Mã SV/HV/NCS là bắt buộc';
    if (!_idPattern.hasMatch(id)) {
      return 'Mã SV/HV/NCS chỉ gồm chữ cái không dấu và chữ số';
    }
    if (id.length < _idMinLength) {
      return 'Mã SV/HV/NCS phải có ít nhất $_idMinLength ký tự';
    }
    if (id.length > _idMaxLength) {
      return 'Mã SV/HV/NCS tối đa $_idMaxLength ký tự';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Địa chỉ email là bắt buộc';
    if (email.length > _emailMaxLength) {
      return 'Địa chỉ email tối đa $_emailMaxLength ký tự';
    }
    if (!email.contains('@')) return 'Địa chỉ email phải có ký tự @';
    if (email.indexOf('@') != email.lastIndexOf('@')) {
      return 'Địa chỉ email chỉ được có một ký tự @';
    }

    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return 'Địa chỉ email thiếu phần tên trước ký tự @';
    if (domain.isEmpty) return 'Địa chỉ email thiếu tên miền sau ký tự @';
    if (local.length > _emailLocalMaxLength) {
      return 'Phần tên trước ký tự @ tối đa $_emailLocalMaxLength ký tự';
    }
    if (!domain.contains('.')) {
      return 'Tên miền email không hợp lệ (vd: ten@hcmute.edu.vn)';
    }
    if (!_emailPattern.hasMatch(email) ||
        email.contains('..') ||
        local.startsWith('.') ||
        local.endsWith('.')) {
      return 'Địa chỉ email không hợp lệ';
    }
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
      if (_validateStudentId(_idCtrl.text) != null) {
        _idFocus.requestFocus();
      } else {
        _emailFocus.requestFocus();
      }
      return;
    }

    setState(() => _loading = true);
    try {
      // Kiểm tra tài khoản + email trên Firestore, rồi gửi OTP vào email.
      final session = await _service.requestReset(
        studentId: _idCtrl.text,
        email: _emailCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(session: session),
        ),
      );
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Quay về form đăng nhập.
  void _backToLogin() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
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
    return AuthPageLayout(
      footerLabel: 'Đăng nhập',
      onFooterTap: _loading ? null : _backToLogin,
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mã SV/HV/NCS
            TextFormField(
              controller: _idCtrl,
              focusNode: _idFocus,
              enabled: !_loading,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(_idMaxLength),
              ],
              onChanged: (_) => _clearServerError(),
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              decoration: authInputDecoration('Mã SV/HV/NCS'),
              validator: _validateStudentId,
            ),
            const SizedBox(height: 20),

            // Địa chỉ email
            TextFormField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(_emailMaxLength),
              ],
              onChanged: (_) => _clearServerError(),
              onFieldSubmitted: (_) => _onSubmit(),
              decoration: authInputDecoration('Địa chỉ email'),
              validator: _validateEmail,
            ),

            // Lỗi từ hệ thống (không tìm thấy tài khoản, sai email, mất mạng...)
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),

            // Nút Gửi mã xác nhận
            AuthPrimaryButton(
              label: 'Gửi mã xác nhận',
              loading: _loading,
              onPressed: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
