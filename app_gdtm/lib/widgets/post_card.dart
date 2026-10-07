// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'attachment_utils.dart';
import 'forum_utils.dart';
import 'post_link.dart';
import 'pdf_view.dart';
import 'reaction_button.dart';

class PostCard extends StatelessWidget {
  final ForumPostDTO post;
  final ValueChanged<String> onReact;

  /// Mở trang chi tiết (ở trang chi tiết thì để null)
  final VoidCallback? onOpen;

  /// Bấm nút "Bình luận" (mặc định = onOpen)
  final VoidCallback? onTapComments;

  /// Bấm vào dòng emoji + số reaction để xem ai đã thả
  final VoidCallback? onShowReactors;

  /// true = hiển thị đầy đủ nội dung (trang chi tiết)
  final bool expanded;

  /// Báo cáo bài viết. Null thì không có mục "Báo cáo" (admin, hoặc không cho báo cáo).
  final VoidCallback? onReport;

  /// Đã báo cáo bài này rồi: mục menu đổi thành "Đã báo cáo" (không bấm được)
  final bool reported;

  /// Chỉ admin: ẩn / hiện lại bài viết. Khác null thì menu có "Ẩn bài viết" / "Hiện lại".
  final VoidCallback? onToggleHidden;

  /// Chạm avatar / tên tác giả -> card thông tin người dùng
  final VoidCallback? onTapAuthor;

  /// Chạm tên phòng ban -> card thông tin phòng ban
  final VoidCallback? onTapDepartment;

  

  const PostCard({
    super.key,
    required this.post,
    required this.onReact,
    this.onOpen,
    this.onTapComments,
    this.onShowReactors,
    this.expanded = false,
    this.onReport,
    this.reported = false,
    this.onToggleHidden,
    this.onTapAuthor,
    this.onTapDepartment,
  });

  bool _isImage(AttachmentDTO a) {
    final t = a.fileType.toLowerCase();
    final u = a.fileUrl.toLowerCase().split('?').first;
    const exts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    return t.contains('image') || exts.any((e) => t == e || u.endsWith('.$e'));
  }

  String _extension(AttachmentDTO file) {
    final type = file.fileType.toLowerCase().replaceAll('.', '');
    if (type.isNotEmpty && !type.contains('/')) return type;
    if (type.contains('pdf')) return 'pdf';
    final name = file.fileName.split('?').first.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) return name.substring(dot + 1);
    final url = file.fileUrl.split('?').first.toLowerCase();
    final urlDot = url.lastIndexOf('.');
    return urlDot >= 0 && urlDot < url.length - 1 ? url.substring(urlDot + 1) : '';
  }

  Future<void> _showFilePreview(BuildContext context, AttachmentDTO file) async {
    final url = file.fileUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đường dẫn tệp không hợp lệ.')),
      );
      return;
    }
    final isPdf = _extension(file) == 'pdf';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined),
              title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: isPdf
                  ? PdfView(url: url)
                  : _UnsupportedFilePreview(onOpen: () => openUrl(context, url)),
            ),
          ]),
        ),
      ),
    );
  }

  /// Có thao tác phụ nào để hiện trong menu ⋯ không
  bool get _hasActions => onToggleHidden != null || (onReport != null && !post.isMine);

  /// Menu thao tác phụ dạng bottom sheet (giống menu ⋯ của bình luận).
  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Admin: ẩn / hiện lại bài viết bất kỳ
          if (onToggleHidden != null)
            ListTile(
              leading: Icon(post.isHidden ? Icons.visibility : Icons.visibility_off),
              title: Text(post.isHidden ? 'Hiện lại bài viết' : 'Ẩn bài viết'),
              subtitle: Text(post.isHidden
                  ? 'Mọi người sẽ thấy lại bài viết này'
                  : 'Chỉ quản trị viên còn thấy, ở dạng mờ'),
              onTap: () {
                Navigator.pop(ctx);
                onToggleHidden!();
              },
            ),
          // Người dùng thường: báo cáo bài của người khác
          if (onReport != null && !post.isMine)
            ListTile(
              enabled: !reported,
              leading: Icon(reported ? Icons.flag : Icons.flag_outlined),
              title: Text(reported ? 'Đã báo cáo' : 'Báo cáo bài viết'),
              subtitle: Text(reported
                  ? 'Bạn đã báo cáo bài viết này'
                  : 'Báo cho quản trị viên xem xét'),
              onTap: reported
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      onReport!();
                    },
            ),
        ]),
      ),
    );
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final imageWidth = isDesktop
      ? 650.0
      : screenWidth;
    final images = post.attachments.where(_isImage).toList();
    final files = post.attachments.where((a) => !_isImage(a)).toList();

    // Bài bị ẩn (chỉ admin nhận được) hiển thị mờ
    return Opacity(
      opacity: post.isHidden ? 0.5 : 1.0,
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
            child: Row(children: [
              GestureDetector(
                onTap: onTapAuthor,
                child: InitialAvatar(name: post.userName, radius: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onTapAuthor,
                        child: Text(post.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    if (post.isHidden) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.visibility_off, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Đã ẩn',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onTapDepartment,
                        child: Text(
                          post.departmentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kFbText2,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Text(' · ${timeAgo(post.date)} · ',
                        maxLines: 1,
                        style: const TextStyle(color: kFbText2, fontSize: 12.5)),
                    const Icon(Icons.public, size: 13, color: kFbText2),
                  ]),
                ]),
              ),
              // Thao tác phụ (báo cáo / ẩn) gom vào menu ⋯
              if (_hasActions)
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: kFbText2),
                  tooltip: 'Tùy chọn',
                  onPressed: () => _showActions(context),
                )
              else
                const SizedBox(width: 8),
            ]),
          ),

          // Nội dung
          InkWell(
            onTap: onOpen,
            onLongPress: () => PostLink.copy(context, post.id), // nhấn giữ = sao chép link
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.subject,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                if (post.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  expanded
                      // Trang chi tiết: link bài viết hiện thành thẻ xem trước
                      ? LinkifiedContent(
                          text: post.description,
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        )
                      // Bảng tin: giữ gọn, link hiện thành "Xem bài viết"
                      : Text.rich(
                          TextSpan(children: linkifySpans(context, post.description)),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        ),
                ],
                if (post.categories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: post.categories
                        .map((c) => Text('#$c',
                            style: const TextStyle(color: kFbBlue, fontSize: 14)))
                        .toList(),
                  ),
                ],
              ]),
            ),
          ),

          // Ảnh đính kèm
          if (images.isNotEmpty)
          GestureDetector(
            onTap: () => _showImageViewer(
              context,
              images.first.fileUrl,
            ),
            child: Center(
              child: Image.network(
                images.first.fileUrl,
                width: imageWidth,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: kFbBg,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image,
                    color: kFbText2,
                  ),
                ),
              ),
            ),
          ),
          // Tệp đính kèm khác
          for (final f in files)
            InkWell(
              onTap: () => _showFilePreview(context, f),
              borderRadius: BorderRadius.circular(8),
              child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kFbBg, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.insert_drive_file_outlined, color: kFbText2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(f.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.visibility_outlined, size: 20, color: kFbText2),
              ]),
              ),
            ),

          // Thống kê
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onShowReactors ?? onOpen,
                  child: ReactionSummary(
                      emojis: post.topReactionIcons, total: post.totalReactions),
                ),
                const Spacer(),
                if (post.commentCount > 0)
                  Text('${post.commentCount} bình luận',
                      style: const TextStyle(color: kFbText2, fontSize: 13)),
              ]),
            ),
          ),

          const Divider(height: 1, indent: 12, endIndent: 12),

          // Hành động
          Row(children: [
            Expanded(child: ReactionButton(current: post.reactionType, onReact: onReact)),
            Expanded(
              child: InkWell(
                onTap: onTapComments ?? onOpen,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.chat_bubble_outline, size: 20, color: kFbText2),
                    SizedBox(width: 6),
                    Text('Bình luận',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: kFbText2)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => PostLink.copy(context, post.id),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.link, size: 20, color: kFbText2),
                    SizedBox(width: 6),
                    Text('Sao chép',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: kFbText2)),
                  ]),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _UnsupportedFilePreview extends StatelessWidget {
  final VoidCallback onOpen;

  const _UnsupportedFilePreview({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 54, color: kFbText2),
          const SizedBox(height: 12),
          const Text('Định dạng này chưa hỗ trợ xem trước.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: kFbText2)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Mở tệp'),
          ),
        ]),
      ),
    );
  }
}
