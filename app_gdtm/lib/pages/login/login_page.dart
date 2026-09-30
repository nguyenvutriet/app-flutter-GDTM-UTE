import 'package:flutter/material.dart';

import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/pages/common/dashboard_page.dart';
import 'package:app_gdtm/services/AuthService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

// Màu riêng của trang đăng nhập (lấy theo giao diện web).
const Color _titleColor = Color(0xFF1B2A41); // tên trường
const Color _headingColor = Color(0xFF3F51A3); // chữ "ĐĂNG NHẬP"
const Color _mutedColor = Color(0xFF6B7A90); // chữ phụ, label
const Color _fieldFill = Color(0xFFE8F0FE); // nền ô nhập
const Color _fieldBorder = Color(0xFF9FB1CB); // viền ô nhập
const Color _cardBorder = Color(0xFFDCDCDC); // viền card
const Color _errorColor = Color(0xFFC62828);

/// Trang đăng nhập (chuyển từ giao diện web "Cổng thông tin đào tạo" sang Flutter).
///
/// Sau khi đăng nhập thành công, điều hướng theo role:
///   ROLE_ADMIN   -> giao diện admin
///   ROLE_TEACHER -> giao diện staff (giảng viên)
///   ROLE_STUDENT -> giao diện student
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIC
  // ============================================================

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signIn(
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      _goToDashboard(result.role);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Chuyển sang giao diện tương ứng với role.
  void _goToDashboard(UserRole role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardPage(role: role)),
    );
  }

  /// Nút "Đăng nhập với Google" — mới chỉ có giao diện.
  /// TODO(google-signin): xem HUONG_DAN_GOOGLE_SIGN_IN.md để cài đặt thật.
  Future<void> _onGoogleSignIn() async {
  if (_loading) return;
  setState(() {
    _loading = true;
    _errorMessage = null;
  });

  try {
    final result = await _authService.signInWithGoogle();
    if (!mounted) return;
    _goToDashboard(result.role);
  } on AuthException catch (e) {
    if (!mounted) return;
    setState(() => _errorMessage = e.message);
  } catch (_) {
    if (!mounted) return;
    setState(() => _errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  /// Nút "Quên mật khẩu".
  /// TODO(forgot-password): thực thi chức năng quên mật khẩu tại đây
  /// (vd: mở trang ForgotPasswordPage, hoặc gửi email đặt lại mật khẩu).
  void _onForgotPassword() {
    _showInfo('Chức năng quên mật khẩu đang được phát triển.');
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 552),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('lib/assets/ute_logo.png', height: 120),
                  const SizedBox(height: 24),
                  Text(
                    'TRƯỜNG ĐẠI HỌC CÔNG NGHỆ KỸ THUẬT TP.HCM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: narrow ? 20 : 24,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildCard(narrow),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(bool narrow) {
    final pad = narrow ? 20.0 : 32.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _cardBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ĐĂNG NHẬP',
              style: TextStyle(
                fontSize: narrow ? 26 : 30,
                fontWeight: FontWeight.w700,
                color: _headingColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cổng thông tin đào tạo',
              style: TextStyle(fontSize: 14, color: _mutedColor),
            ),
            const SizedBox(height: 32),

            // Tên đăng nhập
            TextFormField(
              controller: _usernameCtrl,
              enabled: !_loading,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              decoration: _inputDecoration('Tên đăng nhập'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên đăng nhập'
                  : null,
            ),
            const SizedBox(height: 20),

            // Mật khẩu
            TextFormField(
              controller: _passwordCtrl,
              enabled: !_loading,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: _inputDecoration('Mật khẩu'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
            ),

            // Thông báo lỗi đăng nhập
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: _errorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: _errorColor, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Nút Đăng nhập
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
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
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút Đăng nhập với Google (chỉ có giao diện)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _loading ? null : _onGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _fieldBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('lib/assets/google_g.png', width: 22, height: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Đăng nhập với Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 14),

            // Quên mật khẩu (góc trái dưới form) — TODO: thực thi sau
            InkWell(
              onTap: _onForgotPassword,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Quên mật khẩu',
                  style: TextStyle(fontSize: 14, color: _mutedColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ô nhập kiểu outlined, nền xanh nhạt, label nổi trên viền (giống web).
  InputDecoration _inputDecoration(String label) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _mutedColor, fontSize: 15),
      floatingLabelStyle:
          const TextStyle(color: _mutedColor, fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: border(_fieldBorder),
      disabledBorder: border(_fieldBorder),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(_errorColor),
      focusedErrorBorder: border(_errorColor, 2),
    );
  }
}
