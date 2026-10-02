import 'package:flutter/material.dart';

import 'package:app_gdtm/widgets/app_colors.dart';

// Màu dùng chung cho các trang trong luồng quên mật khẩu (theo giao diện web).
const Color kAuthTitleColor = Color(0xFF1B2A41); // tên trường, tên cổng
const Color kAuthMutedColor = Color(0xFF6B7A90); // chữ phụ, link
const Color kAuthFieldBorder = Color(0xFF9FB1CB); // viền ô nhập bình thường
const Color kAuthCardBorder = Color(0xFFDCDCDC); // viền card
const Color kAuthErrorColor = Color(0xFFE53935); // viền, label, chữ báo lỗi
const Color kAuthSuccessColor = Color(0xFF2E7D32); // báo thành công

/// Khung chung: nền xám, logo + tên trường, card trắng gồm
/// [heading], [subtitle], [body], đường kẻ và link nhỏ ở góc trái dưới card.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.body,
    required this.footerLabel,
    required this.onFooterTap,
    this.heading = 'QUÊN MẬT KHẨU',
    this.subtitle = 'Cổng thông tin đào tạo',
  });

  final Widget body;
  final String heading;
  final String subtitle;

  /// Link nhỏ góc trái dưới card (vd: "Đăng nhập").
  final String footerLabel;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final pad = narrow ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 552),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('lib/assets/ute_logo.png', height: 120),
                  const SizedBox(height: 20),
                  Text(
                    'TRƯỜNG ĐẠI HỌC CÔNG NGHỆ KỸ THUẬT TP.HCM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: narrow ? 15 : 17,
                      fontWeight: FontWeight.w500,
                      color: kAuthTitleColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CỔNG THÔNG TIN ĐÀO TẠO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: narrow ? 19 : 22,
                      fontWeight: FontWeight.w700,
                      color: kAuthTitleColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kAuthCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: TextStyle(
                            fontSize: narrow ? 26 : 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kAuthMutedColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                        body,
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Color(0xFFE0E0E0)),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: onFooterTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              footerLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                color: kAuthMutedColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút xanh toàn chiều rộng; khi [loading] hiện vòng xoay và khoá nút.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
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
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: kAuthErrorColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: kAuthErrorColor, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

/// Style ô nhập dùng chung: nền trắng, viền xám xanh; khi lỗi thì viền, label
/// và dòng báo lỗi đều đỏ (giống web).
InputDecoration authInputDecoration(String label, {Widget? suffixIcon}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  TextStyle labelStyle(Set<WidgetState> states, double size) {
    final isError = states.contains(WidgetState.error);
    return TextStyle(
      color: isError ? kAuthErrorColor : kAuthMutedColor,
      fontSize: size,
    );
  }

  return InputDecoration(
    labelText: label,
    labelStyle: WidgetStateTextStyle.resolveWith((s) => labelStyle(s, 16)),
    floatingLabelStyle:
        WidgetStateTextStyle.resolveWith((s) => labelStyle(s, 14)),
    errorStyle: const TextStyle(color: kAuthErrorColor, fontSize: 12),
    errorMaxLines: 3,
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    enabledBorder: border(kAuthFieldBorder),
    disabledBorder: border(kAuthFieldBorder),
    focusedBorder: border(AppColors.primary, 2),
    errorBorder: border(kAuthErrorColor),
    focusedErrorBorder: border(kAuthErrorColor, 2),
  );
}
