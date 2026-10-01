import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/pages/login/auth_layout.dart';
import 'package:app_gdtm/services/PasswordResetService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

/// Trang nhập mã OTP (bước sau "Quên mật khẩu").
///
/// - 6 ô nhập số; OTP có hiệu lực 1 phút 30 giây ([PasswordResetService.otpLifetime]).
/// - Dưới ô nhập, căn giữa: "Vui lòng nhập mã OTP, 1:30" đếm ngược; về 0:00 thì
///   đổi thành "Bạn chưa nhận được mã? Gửi lại mã". Bấm "Gửi lại mã" sẽ gửi OTP
///   mới vào email và đếm lại từ 1:30.
/// - Nút "Xác nhận" kiểm tra mã. Nhập đúng thì DỪNG TẠI ĐÂY (chưa chuyển sang
///   trang nhập mật khẩu mới - xem TODO ở [_onConfirm]).
/// - Link "Đăng nhập" góc trái dưới card quay thẳng về form đăng nhập.
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key, required this.session});

  final PasswordResetSession session;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  static const int _codeLength = 6;

  final _service = PasswordResetService();
  final _codeCtrl = TextEditingController();
  final _focus = FocusNode();

  Timer? _timer;
  Duration _remaining = Duration.zero;

  bool _resending = false;
  bool _verified = false;

  /// Lỗi hiển thị ngay dưới 6 ô (thiếu số, sai mã, hết hạn, gửi lại thất bại...).
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh); // để ô đang nhập được tô viền
    _remaining = widget.session.remaining;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ============================================================
  // ĐỒNG HỒ ĐẾM NGƯỢC
  // ============================================================

  /// Đếm theo mốc hết hạn của session (không cộng dồn từng giây) nên không
  /// bị lệch khi app bị tạm dừng / chạy nền.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncRemaining());
  }

  void _syncRemaining() {
    if (!mounted) return;
    final remaining = widget.session.remaining;
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero) _timer?.cancel();
  }

  /// 90 giây -> "1:30", 5 giây -> "0:05".
  String _formatRemaining(Duration d) {
    final totalSeconds = (d.inMilliseconds / 1000).ceil();
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ============================================================
  // LOGIC
  // ============================================================

  void _onConfirm() {
    if (_resending) return;

    if (_verified) {
      _showInfo('Xác thực OTP thành công.');
      return;
    }

    final code = _codeCtrl.text;
    if (code.length < _codeLength) {
      setState(() => _codeError = 'Vui lòng nhập đủ $_codeLength chữ số');
      _focus.requestFocus();
      return;
    }

    try {
      _service.verifyOtp(widget.session, code);
    } on OtpVerifyException catch (e) {
      // Sai mã thì xoá ô để nhập lại; hết hạn / bị huỷ thì giữ nguyên số đã nhập.
      if (e.error == OtpError.wrong) _codeCtrl.clear();
      setState(() => _codeError = e.message);
      _syncRemaining(); // mã hết hạn / bị huỷ -> hiện "Gửi lại mã"
      return;
    }

    _timer?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _verified = true;
      _codeError = null;
    });

    // TODO(reset-password): mở trang nhập mật khẩu mới tại đây, truyền
    //   widget.session (có userDocId để cập nhật mật khẩu trên Firestore).
    //   Hiện tại chỉ dừng ở bước xác thực OTP theo yêu cầu.
    _showInfo('Xác thực OTP thành công.');
  }

  Future<void> _onResend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _codeError = null;
    });

    try {
      await _service.resendOtp(widget.session);
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() => _remaining = widget.session.remaining);
      _startTimer();
      _focus.requestFocus();
      _showInfo('Đã gửi mã OTP mới đến ${widget.session.maskedEmail}.');
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      setState(() => _codeError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _codeError = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Quay thẳng về form đăng nhập (trang đầu tiên của stack).
  void _backToLogin() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).popUntil((route) => route.isFirst);
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
    return AuthPageLayout(
      footerLabel: 'Đăng nhập',
      onFooterTap: _backToLogin,
      body: Column(
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
                TextSpan(
                  text: 'Mã xác nhận gồm $_codeLength chữ số đã được gửi đến ',
                ),
                TextSpan(
                  text: widget.session.maskedEmail,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kAuthTitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildCodeBoxes(),

          // Lỗi ngay dưới ô nhập
          if (_codeError != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Text(
                _codeError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kAuthErrorColor, fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Đồng hồ đếm ngược / Gửi lại mã (căn giữa)
          _buildTimerLine(),
          const SizedBox(height: 20),

          AuthPrimaryButton(
            label: 'Xác nhận',
            onPressed: _resending ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  /// 6 ô vẽ từ nội dung của một TextField ẩn nằm đè lên trên. Cách này giúp
  /// bấm vào đâu cũng mở bàn phím, xoá lùi tự nhiên, dán/gợi ý OTP của bàn phím
  /// vẫn dùng được.
  Widget _buildCodeBoxes() {
    final text = _codeCtrl.text;
    final hasError = _codeError != null;
    final activeIndex =
        _focus.hasFocus && !_verified ? text.length.clamp(0, _codeLength - 1) : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final boxWidth =
            ((constraints.maxWidth - gap * (_codeLength - 1)) / _codeLength)
                .clamp(36.0, 56.0)
                .toDouble();
        final boxHeight = (boxWidth * 1.25).clamp(46.0, 64.0).toDouble();

        return SizedBox(
          height: boxHeight,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _codeLength; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _buildBox(
                      width: boxWidth,
                      digit: i < text.length ? text[i] : '',
                      active: i == activeIndex,
                      hasError: hasError,
                    ),
                  ],
                ],
              ),
              // TextField thật (chữ trong suốt) phủ kín vùng 6 ô.
              Positioned.fill(
                child: TextField(
                  controller: _codeCtrl,
                  focusNode: _focus,
                  autofocus: true,
                  readOnly: _verified,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  cursorColor: Colors.transparent,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onChanged: (_) {
                    // Gõ lại thì xoá lỗi cũ.
                    setState(() => _codeError = null);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBox({
    required double width,
    required String digit,
    required bool active,
    required bool hasError,
  }) {
    Color borderColor = kAuthFieldBorder;
    double borderWidth = 1;
    if (_verified) {
      borderColor = kAuthSuccessColor;
    } else if (hasError) {
      borderColor = kAuthErrorColor;
      borderWidth = active ? 2 : 1;
    } else if (active) {
      borderColor = AppColors.primary;
      borderWidth = 2;
    }

    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: kAuthTitleColor,
        ),
      ),
    );
  }

  /// Dòng ngay dưới ô nhập, căn giữa:
  ///   - đã xác thực : "Xác thực OTP thành công"
  ///   - đang gửi lại: "Đang gửi lại mã..."
  ///   - còn hạn     : "Vui lòng nhập mã OTP, 1:30"
  ///   - hết hạn     : "Bạn chưa nhận được mã? Gửi lại mã"
  Widget _buildTimerLine() {
    const style = TextStyle(fontSize: 14, color: kAuthMutedColor);
    final Widget content;

    if (_verified) {
      content = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 18, color: kAuthSuccessColor),
          SizedBox(width: 6),
          Text(
            'Xác thực OTP thành công',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kAuthSuccessColor,
            ),
          ),
        ],
      );
    } else if (_resending) {
      content = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Đang gửi lại mã...', style: style),
        ],
      );
    } else if (_remaining == Duration.zero) {
      content = Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Bạn chưa nhận được mã? ', style: style),
          InkWell(
            onTap: _onResend,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Gửi lại mã',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'Vui lòng nhập mã OTP, '),
            TextSpan(
              text: _formatRemaining(_remaining),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 28),
      alignment: Alignment.center,
      child: content,
    );
  }
}
