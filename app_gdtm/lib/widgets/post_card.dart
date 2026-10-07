// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'forum_utils.dart';
import 'post_link.dart';
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

  @override
  Widget build(BuildContext context) {
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
              onTap: onOpen,
              child: Stack(children: [
                Image.network(
                  images.first.fileUrl,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: kFbBg,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: kFbText2),
                  ),
                ),
                if (images.length > 1)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      child: Text('+${images.length - 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]),
            ),

          // Tệp đính kèm khác
          for (final f in files)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kFbBg, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.insert_drive_file_outlined, color: kFbText2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(f.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
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