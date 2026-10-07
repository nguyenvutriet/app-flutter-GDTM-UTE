import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/services/CloudinaryService.dart';
import 'package:app_gdtm/services/conversation_chat_service.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_viewer_page.dart';

// Màu theo giao diện staff hiện có (staff_list_page.dart).
const Color _blue = Color(0xFF005BAA);
const Color _lightBlue = Color(0xFFEAF4FC);
const Color _textPrimary = Color(0xFF172B4D);
const Color _textSecondary = Color(0xFF667085);
const Color _border = Color(0xFFE3EAF2);
const Color _chatBg = Color(0xFFF1F5F9);
const Color _ownBubble = Color(0xFFE6F0FB);
const Color _ownBubbleBorder = Color(0xFFCFE0F5);
const Color _green = Color(0xFF16A34A);
const Color _red = Color(0xFFDC2626);

/// Tên hiển thị của sinh viên trong khung chat (theo giao diện web).
const String _studentLabel = 'Ẩn danh';

/// Hộp thoại "Trao đổi với sinh viên" của cán bộ (staff).
///
/// Thay cho `_ConversationDialog` cũ trong `feedback_detail_page.dart`, giữ
/// khung hộp thoại như thiết kế (biểu tượng + tiêu đề + nội dung + nút "Đóng"):
///   - Chưa có cuộc trao đổi: "Chưa có cuộc trao đổi nào." + nút "Mở hội thoại".
///   - Bấm "Mở hội thoại": form 2 ô (Chủ đề, Tin nhắn) + nút "Mở hội thoại".
///   - Đã có cuộc trao đổi: khung chat thời gian thực (giống giao diện web),
///     có nút "Đóng trao đổi". Đóng rồi thì cả hai bên chỉ xem, không nhắn tiếp.
class StaffConversationDialog extends StatefulWidget {
  const StaffConversationDialog({
    super.key,
    required this.request,
    required this.staffUserId,
    this.canOperate = true,
    this.service,
  });

  /// Góp ý đang xem.
  final Request request;

  /// Mã tài khoản cán bộ đang đăng nhập (widget.staffUserId của StaffListPage).
  final String staffUserId;

  /// Staff hiện tại có được thao tác trên góp ý này không (truyền
  /// `_canOperateRequest` của trang chi tiết). `false` = chỉ xem: không mở
  /// hội thoại, không nhắn, không đóng trao đổi.
  final bool canOperate;

  /// Cho phép truyền service riêng (mặc định tự tạo).
  final ConversationChatService? service;

  @override
  State<StaffConversationDialog> createState() =>
      _StaffConversationDialogState();
}

class _StaffConversationDialogState extends State<StaffConversationDialog> {
  late final ConversationChatService _service = widget.service ?? ConversationChatService();

  Stream<List<ConversationInfo>>? _stream;

  /// Đang ở form "Mở hội thoại" (chỉ dùng khi chưa có cuộc trao đổi nào).
  bool _composing = false;

  /// Cuộc trao đổi đang xem (khi một góp ý có nhiều cuộc).
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final requestId = widget.request.id;
    if (requestId != null && requestId.trim().isNotEmpty) {
      _stream = _service.watchConversations(requestId);
    }
  }

  String _streamError(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Không có quyền truy cập dữ liệu trao đổi. '
          'Hãy kiểm tra Firestore Rules.';
    }
    return 'Không tải được dữ liệu trao đổi. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final insetH = media.size.width < 600 ? 16.0 : 40.0;
    const contentH = 20.0;

    final width = math.max(240.0, math.min(650.0, media.size.width - insetH * 2 - contentH * 2));
    // Trừ phần bàn phím và khoảng đệm hộp thoại để khung không bị tràn.
    final height = (media.size.height - media.viewInsets.bottom - 200)
        .clamp(200.0, 640.0)
        .toDouble();

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: insetH, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(contentH, 12, contentH, 8),
      content: SizedBox(width: width, height: height, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final stream = _stream;
    if (stream == null) {
      return const _CenterText('Góp ý không hợp lệ.');
    }

    return StreamBuilder<List<ConversationInfo>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenterText(_streamError(snapshot.error), isError: true);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final conversations = snapshot.data!;

        // Chưa có cuộc trao đổi nào.
        if (conversations.isEmpty) {
          if (_composing && widget.canOperate) {
            return _OpenConversationForm(
              service: _service,
              request: widget.request,
              staffUserId: widget.staffUserId,
              onCancel: () => setState(() => _composing = false),
              onOpened: () => setState(() => _composing = false),
            );
          }
          return _EmptyState(
            canOpen: widget.canOperate,
            onOpen: () => setState(() => _composing = true),
          );
        }

        // Đã có: hiện khung chat (mặc định cuộc mới nhất).
        final selected = conversations.firstWhere(
          (c) => c.docId == _selectedId,
          orElse: () => conversations.first,
        );

        if (_composing && widget.canOperate) {
          return _OpenConversationForm(
            service: _service,
            request: widget.request,
            staffUserId: widget.staffUserId,
            onCancel: () => setState(() => _composing = false),
            onOpened: () => setState(() => _composing = false),
          );
        }

        return Column(
          children: [
            if (conversations.length > 1) ...[
              _ConversationChips(
                conversations: conversations,
                selectedId: selected.docId,
                onSelected: (id) => setState(() => _selectedId = id),
              ),
              const SizedBox(height: 8),
            ],
            if (!selected.isOpen && widget.canOperate)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _composing = true),
                  icon: const Icon(Icons.add_comment_outlined, size: 17),
                  label: const Text('Mở hội thoại mới'),
                ),
              ),
            Expanded(
              child: _ConversationChat(
                key: ValueKey(selected.docId),
                conversation: selected,
                request: widget.request,
                staffUserId: widget.staffUserId,
                canOperate: widget.canOperate,
                service: _service,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// CHƯA CÓ TRAO ĐỔI
// ============================================================

class _CenterText extends StatelessWidget {
  const _CenterText(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: isError ? _red : _textSecondary),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen, required this.canOpen});

  final VoidCallback onOpen;

  /// `false` khi staff không còn quyền xử lý góp ý (chỉ xem).
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chưa có cuộc trao đổi nào.',
            style: TextStyle(color: _textSecondary),
          ),
          const SizedBox(height: 16),
          if (canOpen)
            FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(backgroundColor: _blue),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Mở hội thoại'),
            )
          else
            const _InfoNotice(
              icon: Icons.lock_outline,
              text:
                  'Phòng ban của bạn không còn quyền xử lý góp ý này '
                  'nên không thể mở hội thoại.',
            ),
        ],
      ),
    );
  }
}

// ============================================================
// FORM MỞ HỘI THOẠI (Chủ đề + Tin nhắn)
// ============================================================

class _OpenConversationForm extends StatefulWidget {
  const _OpenConversationForm({
    required this.service,
    required this.request,
    required this.staffUserId,
    required this.onCancel,
    required this.onOpened,
  });

  final ConversationChatService service;
  final Request request;
  final String staffUserId;
  final VoidCallback onCancel;
  final VoidCallback onOpened;

  @override
  State<_OpenConversationForm> createState() => _OpenConversationFormState();
}

class _OpenConversationFormState extends State<_OpenConversationForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.service.openConversation(
        requestId: widget.request.id ?? '',
        subject: _subjectCtrl.text,
        firstMessage: _messageCtrl.text,
        senderId: widget.staffUserId,
        receiverId: widget.request.userId ?? '',
      );
      if (!mounted) return;
      // Cuộc trao đổi mới sẽ tự hiện nhờ stream thời gian thực.
      widget.onOpened();
    } on ConversationChatException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, {bool multiline = false}) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      alignLabelWithHint: multiline,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: border(_border),
      disabledBorder: border(_border),
      focusedBorder: border(_blue, 2),
      errorBorder: border(_red),
      focusedErrorBorder: border(_red, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mở hội thoại với sinh viên',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Nhập chủ đề và tin nhắn đầu tiên để bắt đầu trao đổi.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectCtrl,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  ConversationChatService.maxSubjectLength,
                ),
              ],
              decoration: _decoration('Chủ đề'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Vui lòng nhập chủ đề' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _messageCtrl,
              enabled: !_loading,
              minLines: 4,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  ConversationChatService.maxMessageLength,
                ),
              ],
              decoration: _decoration('Tin nhắn', multiline: true),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Vui lòng nhập tin nhắn'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: _red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loading ? null : widget.onCancel,
                  child: const Text('Quay lại'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Mở hội thoại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHỌN CUỘC TRAO ĐỔI (chỉ hiện khi một góp ý có nhiều cuộc)
// ============================================================

class _ConversationChips extends StatelessWidget {
  const _ConversationChips({
    required this.conversations,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ConversationInfo> conversations;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final c = conversations[index];
          final title = c.subject.isEmpty ? 'Trao đổi ${index + 1}' : c.subject;
          return ChoiceChip(
            selected: c.docId == selectedId,
            onSelected: (_) => onSelected(c.docId),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                c.isOpen ? title : '$title (đã đóng)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// KHUNG CHAT THỜI GIAN THỰC
// ============================================================

class _ConversationChat extends StatefulWidget {
  const _ConversationChat({
    super.key,
    required this.conversation,
    required this.request,
    required this.staffUserId,
    required this.canOperate,
    required this.service,
  });

  final ConversationInfo conversation;
  final Request request;
  final String staffUserId;
  final bool canOperate;
  final ConversationChatService service;

  @override
  State<_ConversationChat> createState() => _ConversationChatState();
}

class _ConversationChatState extends State<_ConversationChat> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _files = <PlatformFile>[];

  late final Stream<List<ConversationMessage>> _messages = widget.service
      .watchMessages(widget.conversation);

  bool _sending = false;
  bool _closing = false;
  String? _error;

  /// Họ tên theo mã người gửi (tải dần, có cache trong service).
  final Map<String, String> _names = {};
  final Set<String> _requestedNames = {};

  @override
  void initState() {
    super.initState();
    _resolveName(widget.staffUserId);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _resolveName(String id) {
    if (id.isEmpty || _requestedNames.contains(id)) return;
    _requestedNames.add(id);
    widget.service.getUserName(id).then((name) {
      if (!mounted || name == null) return;
      setState(() => _names[id] = name);
    });
  }

  // ------------------------------------------------------------
  // GỬI TIN NHẮN
  // ------------------------------------------------------------

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final files = [..._files, ...result.files];
    final error = CloudinaryService.validateFiles(files);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _files
        ..clear()
        ..addAll(files);
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _files.isEmpty) return;

    final receiverId = widget.request.userId ?? '';
    if (receiverId.isEmpty) {
      setState(() => _error = 'Góp ý không có mã sinh viên nên không thể gửi.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    _inputCtrl.clear();

    try {
      final uploads = await CloudinaryService().uploadFiles(
        _files,
        folder: CloudinaryConfig.conversationFolder,
        ownerId: widget.conversation.docId,
      );
      await widget.service.sendMessage(
        conversation: widget.conversation,
        senderId: widget.staffUserId,
        receiverId: receiverId,
        content: text,
        attachments: uploads
            .map(
              (file) => FileAttachment(
                filename: file.fileName,
                fileUrl: file.secureUrl,
                filestype: file.fileType,
                filesize: file.bytes,
                publicId: file.publicId,
                resourceType: file.resourceType,
                deleteToken: file.deleteToken,
              ),
            )
            .toList(),
      );
      _files.clear();
    } on ConversationChatException catch (e) {
      if (!mounted) return;
      _restoreInput(text);
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      _restoreInput(text);
      setState(() => _error = 'Không gửi được tin nhắn, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (widget.conversation.isOpen) _inputFocus.requestFocus();
      }
    }
  }

  /// Gửi lỗi thì trả lại nội dung đã gõ (nếu ô nhập đang trống).
  void _restoreInput(String text) {
    if (_inputCtrl.text.isNotEmpty) return;
    _inputCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đóng hội thoại?'),
        content: const Text(
          'Sau khi đóng, sinh viên và cán bộ chỉ có thể xem lại nội dung '
          'và không thể nhắn tiếp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _red),
            child: const Text('Đóng hội thoại'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _closing = true;
      _error = null;
    });
    try {
      await widget.service.closeConversation(widget.conversation);
    } on ConversationChatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đóng được hội thoại, vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.conversation.isOpen;

    return Column(
      children: [
        _buildHeader(isOpen),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _chatBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildMessages(),
          ),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 16, color: _red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: _red, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        if (!isOpen)
          _buildClosedNotice()
        else if (!widget.canOperate)
          const _InfoNotice(
            icon: Icons.lock_outline,
            text:
                'Phòng ban của bạn không còn quyền xử lý góp ý này nên '
                'chỉ có thể xem trao đổi, không thể nhắn tiếp.',
          )
        else
          _buildComposer(),
      ],
    );
  }

  /// Tiêu đề và trạng thái cuộc trao đổi.
  Widget _buildHeader(bool isOpen) {
    final subject = widget.conversation.subject;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.isEmpty ? 'Cuộc trao đổi' : subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: _textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'Trạng thái: '),
              TextSpan(
                text: isOpen ? 'Đang mở' : 'Đã đóng',
                style: TextStyle(
                  color: isOpen ? _green : _textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!isOpen || !widget.canOperate) {
      return Align(alignment: Alignment.centerLeft, child: info);
    }

    final closeButton = OutlinedButton.icon(
      onPressed: _closing ? null : _confirmClose,
      style: OutlinedButton.styleFrom(
        foregroundColor: _red,
        side: const BorderSide(color: _red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: _closing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _red),
            )
          : const Icon(Icons.check_circle_outline, size: 15),
      label: Text('Đóng', style: const TextStyle(fontSize: 12)),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: info),
        const SizedBox(width: 6),
        closeButton,
      ],
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<ConversationMessage>>(
      stream: _messages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _CenterText(
            'Không tải được tin nhắn. Vui lòng thử lại.',
            isError: true,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!;
        if (messages.isEmpty) {
          return const _CenterText('Chưa có tin nhắn.');
        }

        // Danh sách đảo chiều: tin mới nhất nằm sát ô nhập và tự bám đáy.
        final reversed = messages.reversed.toList();

        return LayoutBuilder(
          builder: (context, box) {
            final maxBubble = box.maxWidth * 0.82;
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: reversed.length,
              itemBuilder: (_, index) =>
                  _buildBubble(reversed[index], maxBubble),
            );
          },
        );
      },
    );
  }

  Widget _buildBubble(ConversationMessage message, double maxWidth) {
    final studentId = widget.request.userId ?? '';
    final mine = message.senderId == widget.staffUserId;
    final isStudent =
        !mine && studentId.isNotEmpty && message.senderId == studentId;

    final String name;
    if (mine) {
      name = _names[message.senderId] ?? 'Bạn';
    } else if (isStudent) {
      name = _studentLabel;
    } else {
      _resolveName(message.senderId); // cán bộ khác cùng xử lý góp ý
      name = _names[message.senderId] ?? 'Cán bộ';
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: mine ? _ownBubble : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mine ? _ownBubbleBorder : _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                message.content,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              ...message.attachments.map(_attachment),
              const SizedBox(height: 6),
              Text(
                _formatTime(message.createAt),
                style: const TextStyle(color: _textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachment(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    final extension = attachmentExt(file);
    final isImage = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(extension);

    if (isImage && url.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tải được hình ảnh.'),
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 260,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fileLink(file),
            ),
          ),
        ),
      );
    }
    return _fileLink(file);
  }

  Widget _fileLink(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () {
              if (isPdf(file)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                      url: url,
                      title: file.filename ?? 'Tài liệu PDF',
                    ),
                  ),
                );
              } else {
                openUrl(context, url);
              }
            },
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kindIcon(attachmentKind(file)),
              size: 19,
              color: kindColor(attachmentKind(file)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                file.filename ?? 'Tệp đính kèm',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ô nhập tin nhắn + nút gửi (chỉ hiện khi cuộc trao đổi đang mở).
  Widget _buildComposer() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      children: [
        if (_files.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              children: _files
                  .map(
                    (file) => Chip(
                      label: Text(file.name, overflow: TextOverflow.ellipsis),
                      onDeleted: _sending
                          ? null
                          : () => setState(() => _files.remove(file)),
                    ),
                  )
                  .toList(),
            ),
          ),
        Row(
          children: [
            IconButton(
              tooltip: 'Đính kèm tệp',
              onPressed: _sending ? null : _pickFiles,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    ConversationChatService.maxMessageLength,
                  ),
                ],
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: const TextStyle(color: _textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  enabledBorder: border(_border),
                  focusedBorder: border(_blue, 1.6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: _sending ? _blue.withValues(alpha: 0.6) : _blue,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _sending ? null : _send,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Thay cho ô nhập khi cuộc trao đổi đã đóng (khoá cả hai bên).
  Widget _buildClosedNotice() {
    return const _InfoNotice(
      icon: Icons.lock_outline,
      text:
          'Cuộc trao đổi đã được đóng. Bạn chỉ có thể xem lại nội dung, '
          'không thể nhắn tiếp.',
    );
  }

  /// dd/MM/yyyy HH:mm:ss (giống giao diện web).
  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// Khung thông báo nhỏ (ổ khoá + nội dung) dùng cho các trạng thái chỉ xem.
class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
