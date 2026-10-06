import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/ClarificationConversation.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Message.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/pages/student/post_detail_page.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/page_title.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_view.dart';

class FeedbackDetailPage extends StatefulWidget {
  final Request request;
  final Users user;
  final List<Department> departments;
  final List<Category> categories;
  final VoidCallback? onBack;

  const FeedbackDetailPage({
    super.key,
    required this.request,
    required this.user,
    required this.departments,
    required this.categories,
    this.onBack,
  });

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final _service = RequestService();
  late Future<FeedbackDetails> _details;

  // ============================================================
  // HCMUTE ONLINE COLOR PALETTE
  // ============================================================

  static const Color hcmuteBlue = Color(0xFF005BAA);
  static const Color hcmuteLightBlue = Color(0xFFEAF4FC);

  static const Color pageBackground = Color(0xFFF4F7FB);
  static const Color textPrimary = Color(0xFF172B4D);
  static const Color textSecondary = Color(0xFF667085);
  static const Color borderColor = Color(0xFFE3EAF2);

  @override
  void initState() {
    super.initState();
    _details = _service.getFeedbackDetails(widget.request);
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _date(DateTime? value) {
    if (value == null) return 'Chưa cập nhật';

    final date = value.toLocal();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _statusLabel(String? status) {
    switch (status) {
      case 'PENDING':
        return 'Đang chờ tiếp nhận';

      case 'FORWARDING':
        return 'Đã được chuyển tiếp';

      case 'APPROVED':
        return 'Đang xử lý';

      case 'RESOLVED':
        return 'Đã xử lý';

      case 'REJECTED':
        return 'Từ chối';

      default:
        return status ?? 'Chưa cập nhật';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'RESOLVED':
        return const Color(0xFF16A34A);

      case 'REJECTED':
        return const Color(0xFFDC2626);

      case 'APPROVED':
        return hcmuteBlue;

      case 'FORWARDING':
        return const Color(0xFFF59E0B);

      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule_outlined;

      case 'FORWARDING':
        return Icons.forward_outlined;

      case 'APPROVED':
        return Icons.autorenew_rounded;

      case 'RESOLVED':
        return Icons.check_circle_outline;

      case 'REJECTED':
        return Icons.cancel_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // DEPARTMENT / CATEGORY
  // ============================================================

  String get _departmentName =>
      widget.departments
          .where((department) => department.id == widget.request.departmentId)
          .map((department) => department.name ?? '')
          .firstOrNull ??
      'Chưa xác định phòng ban';

  String get _categoryNames => widget.request.categoryIds
      .map(
        (id) => widget.categories
            .where((category) => category.id == id)
            .map((category) => category.subject)
            .firstOrNull,
      )
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .join(', ');

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;

          final double horizontalPadding = isDesktop
              ? 48
              : constraints.maxWidth >= 600
              ? 28
              : 16;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              40,
            ),
            children: [
              _buildTopHeader(),
              const SizedBox(height: 18),

              _buildBackButton(),

              const SizedBox(height: 14),

              _buildSummary(),

              const SizedBox(height: 16),

              FutureBuilder<FeedbackDetails>(
                future: _details,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoading();
                  }

                  if (snapshot.hasError) {
                    return _DetailError(
                      message: 'Không tải được chi tiết: ${snapshot.error}',
                      onRetry: () {
                        setState(() {
                          _details = _service.getFeedbackDetails(
                            widget.request,
                          );
                        });
                      },
                    );
                  }

                  final details = snapshot.data ?? const FeedbackDetails();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDescription(),

                      const SizedBox(height: 16),

                      _buildAttachments(details),

                      const SizedBox(height: 16),

                      _buildBottomSection(details),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return const PageTitle('CHI TIẾT GÓP Ý');
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: widget.onBack ?? () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hcmuteLightBlue,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 19,
                  color: hcmuteBlue,
                ),
              ),

              const SizedBox(width: 9),

              const Text(
                'Quay lại lịch sử góp ý',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hcmuteBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final statusColor = _statusColor(widget.request.currentStatus);

    final isPublic =
        widget.request.postStatus == RequestService.postStatusPublic;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Thanh màu HCMUTE
          Container(
            height: 5,
            decoration: const BoxDecoration(
              color: hcmuteBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.subject ?? 'Không có tiêu đề',
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 18),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatusBadge(
                      icon: _statusIcon(widget.request.currentStatus),
                      text: _statusLabel(widget.request.currentStatus),
                      color: statusColor,
                    ),

                    _StatusBadge(
                      icon: isPublic
                          ? Icons.public_outlined
                          : Icons.account_balance_outlined,
                      text: isPublic ? 'Công khai' : 'Gửi đến phòng ban',
                      color: hcmuteBlue,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Divider(height: 1, color: borderColor),

                const SizedBox(height: 18),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool twoColumns = constraints.maxWidth >= 650;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _InfoItem(
                            icon: Icons.schedule_outlined,
                            title: 'Thời gian gửi',
                            value: _date(widget.request.timeCreate),
                          ),
                        ),

                        SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _InfoItem(
                            icon: Icons.account_balance_outlined,
                            title: 'Phòng ban',
                            value: _departmentName,
                          ),
                        ),

                        SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _InfoItem(
                            icon: Icons.category_outlined,
                            title: 'Danh mục',
                            value: _categoryNames.isEmpty
                                ? 'Chưa phân loại'
                                : _categoryNames,
                          ),
                        ),

                        SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _InfoItem(
                            icon: Icons.location_on_outlined,
                            title: 'Địa điểm',
                            value: widget.request.location?.isNotEmpty == true
                                ? widget.request.location!
                                : 'Chưa cập nhật',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescription() {
    final description = widget.request.description?.isNotEmpty == true
        ? widget.request.description!
        : 'Chưa có nội dung.';

    return _SectionCard(
      title: 'Nội dung góp ý',
      icon: Icons.description_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE8EEF5)),
        ),
        child: Text(
          description,
          style: const TextStyle(
            fontSize: 15,
            height: 1.65,
            color: textPrimary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  Widget _buildAttachments(FeedbackDetails details) {
    return _SectionCard(
      title: 'Tệp đính kèm',
      icon: Icons.attach_file_rounded,
      child: details.attachments.isEmpty
          ? _EmptyState(
              icon: Icons.folder_open_outlined,
              text: 'Không có tệp đính kèm.',
            )
          : Column(
              children: details.attachments
                  .map(
                    (file) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: hcmuteLightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.insert_drive_file_outlined,
                            color: hcmuteBlue,
                          ),
                        ),
                        title: Text(
                          file.filename ?? 'Tệp đính kèm',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          file.filestype?.isNotEmpty == true
                              ? file.filestype!
                              : 'Tệp đính kèm',
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                        trailing: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Icon(
                            Icons.open_in_new_rounded,
                            size: 17,
                            color: hcmuteBlue,
                          ),
                        ),
                        onTap: file.fileUrl == null
                            ? null
                            : () => _showAttachmentPreview(file),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  // ============================================================
  // BOTTOM SECTION
  // ============================================================

  Widget _buildBottomSection(FeedbackDetails details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = constraints.maxWidth >= 850;

        if (twoColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTimeline(details)),
              const SizedBox(width: 16),
              Expanded(child: _buildConversations(details)),
            ],
          );
        }

        return Column(
          children: [
            _buildTimeline(details),
            const SizedBox(height: 16),
            _buildConversations(details),
          ],
        );
      },
    );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget _buildTimeline(FeedbackDetails details) {
    return _SectionCard(
      title: 'Lịch sử xử lý',
      icon: Icons.timeline_rounded,
      child: details.histories.isEmpty
          ? _EmptyState(
              icon: Icons.history_toggle_off,
              text: 'Chưa có lịch sử xử lý.',
            )
          : Column(
              children: List.generate(details.histories.length, (index) {
                final item = details.histories[index];

                final bool isLast = index == details.histories.length - 1;

                final color = _statusColor(item.status);

                return _TimelineItem(
                  title: _statusLabel(item.status),
                  date: _date(item.createAt),
                  color: color,
                  icon: _statusIcon(item.status),
                  isLast: isLast,
                );
              }),
            ),
    );
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Widget _buildConversations(FeedbackDetails details) {
    if (widget.request.postStatus == RequestService.postStatusPublic) {
      return _SectionCard(
        title: 'Trao đổi',
        icon: Icons.forum_outlined,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hcmuteLightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hcmuteBlue.withValues(alpha: .12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.public, color: hcmuteBlue),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Góp ý đã được công khai',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                'Nội dung góp ý này đã được đăng lên diễn đàn.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: textSecondary,
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: hcmuteBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: _openForumPost,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Xem bài đăng'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Trao đổi',
      icon: Icons.forum_outlined,
      child: details.conversations.isEmpty
          ? _EmptyState(
              icon: Icons.forum_outlined,
              text: 'Chưa có cuộc hội thoại nào.',
            )
          : Column(
              children: details.conversations.map(_buildConversation).toList(),
            ),
    );
  }

  Widget _buildConversation(ClarificationConversation conversation) {
    final bool open = conversation.isOpen == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(11)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(11)),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: open ? const Color(0xFFEAF8F0) : const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            open ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 19,
            color: open ? const Color(0xFF16A34A) : textSecondary,
          ),
        ),
        title: Text(
          conversation.subject ?? 'Cuộc hội thoại',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          open ? 'Đang mở' : 'Đã đóng',
          style: TextStyle(
            fontSize: 12,
            color: open ? const Color(0xFF16A34A) : textSecondary,
          ),
        ),
        children: conversation.messages.isEmpty
            ? [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Chưa có tin nhắn.',
                      style: TextStyle(color: textSecondary),
                    ),
                  ),
                ),
              ]
            : conversation.messages.map(_messageTile).toList(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget _messageTile(Message message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content ?? '—',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 13,
                color: textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _date(message.createAt),
                style: const TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: hcmuteBlue, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text(
              'Đang tải thông tin...',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPEN FORUM POST
  // ============================================================

  Future<void> _openForumPost() async {
    final id = widget.request.id;

    if (id == null) return;

    final service = ForumService(currentUserId: () => widget.user.id);

    try {
      final post = await service.getPostDetail(id);

      if (!mounted) return;

      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bài đăng không còn tồn tại.')),
        );

        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(initialPost: post, service: service),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được bài đăng: $error')));
    }
  }

  // ============================================================
  // ATTACHMENT PREVIEW
  // ============================================================

  void _showAttachmentPreview(FileAttachment file) {
    final url = file.fileUrl?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy đường dẫn tệp.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đường dẫn tệp không hợp lệ.')),
      );
      return;
    }

    final extension = attachmentExt(file);
    final isImage = const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(extension);
    final isPdfFile = extension == 'pdf';
    final Widget preview;

    if (isPdfFile) {
      preview = PdfView(url: url);
    } else if (isImage) {
      preview = InteractiveViewer(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _AttachmentPreviewError(),
        ),
      );
    } else {
      preview = _UnsupportedAttachmentPreview(
        onOpen: () => openUrl(context, url),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Row(
                  children: [
                    Icon(
                      isPdfFile
                          ? Icons.picture_as_pdf
                          : isImage
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      color: hcmuteBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.filename ?? 'Tệp đính kèm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(child: preview),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedAttachmentPreview extends StatelessWidget {
  final VoidCallback onOpen;

  const _UnsupportedAttachmentPreview({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 54,
              color: Color(0xFF98A2B3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Định dạng này chưa hỗ trợ xem trước.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Mở tệp'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreviewError extends StatelessWidget {
  const _AttachmentPreviewError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Không thể tải bản xem trước của tệp.',
        style: TextStyle(color: Color(0xFF667085)),
      ),
    );
  }
}

// ================================================================
// SECTION CARD
// ================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  static const Color hcmuteBlue = Color(0xFF005BAA);

  static const Color textPrimary = Color(0xFF172B4D);

  static const Color borderColor = Color(0xFFE3EAF2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 19, color: hcmuteBlue),
              ),

              const SizedBox(width: 10),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          child,
        ],
      ),
    );
  }
}

// ================================================================
// INFO ITEM
// ================================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color hcmuteBlue = Color(0xFF005BAA);

  static const Color textPrimary = Color(0xFF172B4D);

  static const Color textSecondary = Color(0xFF667085);

  static const Color borderColor = Color(0xFFE3EAF2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: hcmuteBlue),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STATUS BADGE
// ================================================================

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),

          const SizedBox(width: 6),

          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// TIMELINE ITEM
// ================================================================

class _TimelineItem extends StatelessWidget {
  final String title;
  final String date;
  final Color color;
  final IconData icon;
  final bool isLast;

  const _TimelineItem({
    required this.title,
    required this.date,
    required this.color,
    required this.icon,
    required this.isLast,
  });

  static const Color textPrimary = Color(0xFF172B4D);

  static const Color textSecondary = Color(0xFF667085);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),

                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: color.withValues(alpha: .18),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 13,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EMPTY STATE
// ================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF98A2B3)),

          const SizedBox(height: 8),

          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D0D0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Color(0xFFDC2626),
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF005BAA),
              side: const BorderSide(color: Color(0xFF005BAA)),
            ),
          ),
        ],
      ),
    );
  }
}
