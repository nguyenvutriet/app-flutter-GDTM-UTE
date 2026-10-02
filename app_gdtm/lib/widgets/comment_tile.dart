// lib/widgets/comment_tile.dart
// Bình luận kiểu Facebook: bong bóng xám, Thích · Phản hồi · ⋯ (menu: báo cáo / ẩn / xóa), reply thụt lề.
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'forum_utils.dart';
import 'reaction_button.dart';

class CommentTile extends StatelessWidget {
  final CommentDTO comment;
  final bool isReply;
  final void Function(CommentDTO comment, String type) onReact;
  final ValueChanged<CommentDTO> onReply;
  final ValueChanged<CommentDTO> onDelete;
  final ValueChanged<CommentDTO>? onShowReactors;

  /// Null thì ẩn nút "Báo cáo". Chỉ hiện ở bình luận của người khác.
  final ValueChanged<CommentDTO>? onReport;

  /// Id các bình luận đã báo cáo: hiện "Đã báo cáo" thay cho "Báo cáo"
  final Set<String>? reportedIds;

  /// Chỉ admin: ẩn / hiện lại bình luận. Khác null thì hiện nút "Ẩn bình luận" / "Hiện lại".
  final ValueChanged<CommentDTO>? onToggleHidden;

  /// Bình luận cha đang bị ẩn (các phản hồi bên dưới cũng hiển thị mờ cho admin)
  final bool parentHidden;

  /// Id bình luận cần làm nổi bật (khi admin bấm "Xem" từ trang báo cáo)
  final String? highlightId;

  /// Bảng GlobalKey theo id bình luận để trang cha cuộn tới đúng bình luận
  final Map<String, GlobalKey>? anchors;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    this.onShowReactors,
    this.onReport,
    this.reportedIds,
    this.onToggleHidden,
    this.parentHidden = false,
    this.highlightId,
    this.anchors,
    this.isReply = false,
  });

  /// Có thao tác phụ nào để hiện trong menu ⋯ không
  bool get _hasActions =>
      comment.canDelete || onToggleHidden != null || onReport != null;

  /// Menu thao tác phụ dạng bottom sheet (giống Facebook / Instagram trên điện thoại).
  Future<void> _showActions(BuildContext context) async {
    final c = comment;
    final reported = reportedIds?.contains(c.id) ?? false;
    const red = Color(0xFFD93025);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Admin: ẩn / hiện lại bình luận bất kỳ
          if (onToggleHidden != null)
            ListTile(
              leading: Icon(c.isHidden ? Icons.visibility : Icons.visibility_off),
              title: Text(c.isHidden ? 'Hiện lại bình luận' : 'Ẩn bình luận'),
              subtitle: Text(c.isHidden
                  ? 'Mọi người sẽ thấy lại bình luận này'
                  : 'Chỉ quản trị viên còn thấy, ở dạng mờ'),
              onTap: () {
                Navigator.pop(ctx);
                onToggleHidden!(c);
              },
            ),
          // Người dùng thường: báo cáo bình luận của người khác
          if (onReport != null && !c.canDelete)
            ListTile(
              enabled: !reported,
              leading: Icon(reported ? Icons.flag : Icons.flag_outlined),
              title: Text(reported ? 'Đã báo cáo' : 'Báo cáo bình luận'),
              subtitle: Text(reported
                  ? 'Bạn đã báo cáo bình luận này'
                  : 'Báo cho quản trị viên xem xét'),
              onTap: reported
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      onReport!(c);
                    },
            ),
          // Chủ bình luận: xóa
          if (c.canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: red),
              title: const Text('Xóa bình luận', style: TextStyle(color: red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(c);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = comment;
    // Chỉ hiện @tên khi trả lời một reply (không phải bình luận gốc)
    final showMention =
        c.isReply && c.replyToUsername != null && c.replyId != c.parentId;

    // Admin = đỏ, giảng viên = xanh
    final Color? roleColor = c.isAdmin
        ? const Color(0xFFD32F2F)
        : (c.isTeacher ? kFbBlue : null);
    final bool isFocus = highlightId != null && highlightId == c.id;
    // Bình luận bị ẩn (chỉ admin nhận được) hiển thị mờ
    final bool dim = c.isHidden || parentHidden;
    final Color bubbleColor = isFocus
        ? const Color(0xFFFFF4CC)
        : (c.isAdmin
            ? const Color(0xFFFDECEA)
            : (c.isTeacher ? const Color(0xFFE7F3FF) : kFbBg));
    final String? roleLabel =
        c.isAdmin ? 'Quản trị viên' : (c.isTeacher ? 'Giảng viên' : null);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      KeyedSubtree(
        key: anchors?.putIfAbsent(c.id, () => GlobalKey()),
        child: Opacity(
        opacity: dim ? 0.45 : 1.0,
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InitialAvatar(name: c.userName, radius: isReply ? 14 : 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onLongPress: _hasActions ? () => _showActions(context) : null,
                child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(c.userName,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: roleColor)),
                      ),
                      if (c.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 14, color: roleColor ?? kFbBlue),
                      ],
                      if (roleLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: roleColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(roleLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                      if (c.isHidden) ...[
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
                    Text.rich(TextSpan(children: [
                      if (showMention)
                        TextSpan(
                          text: '${c.replyToUsername} ',
                          style: const TextStyle(
                              color: kFbBlue, fontWeight: FontWeight.w600),
                        ),
                      TextSpan(text: c.content),
                    ]), style: const TextStyle(fontSize: 14.5, height: 1.3)),
                  ]),
                ),
              )),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Wrap(
                  spacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(timeAgo(c.date),
                        style: const TextStyle(fontSize: 12, color: kFbText2)),
                    ReactionButton(
                      compact: true,
                      current: c.reactionType,
                      onReact: (t) => onReact(c, t),
                    ),
                    GestureDetector(
                      onTap: () => onReply(c),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Phản hồi',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kFbText2)),
                      ),
                    ),
                    // Các thao tác phụ (báo cáo / ẩn / xóa) gom vào menu ⋯
                    if (_hasActions)
                      GestureDetector(
                        onTap: () => _showActions(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                          child: Icon(Icons.more_horiz, size: 18, color: kFbText2),
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onShowReactors == null ? null : () => onShowReactors!(c),
                      child: ReactionSummary(
                        emojis: topReactionEmojis(c.reactions),
                        total: c.totalReactions,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ))),
      if (c.replies.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Column(
            children: c.replies
                .map((r) => CommentTile(
                      comment: r,
                      isReply: true,
                      onReact: onReact,
                      onReply: onReply,
                      onDelete: onDelete,
                      onShowReactors: onShowReactors,
                      onReport: onReport,
                      reportedIds: reportedIds,
                      onToggleHidden: onToggleHidden,
                      parentHidden: c.isHidden || parentHidden,
                      highlightId: highlightId,
                      anchors: anchors,
                    ))
                .toList(),
          ),
        ),
    ]);
  }
}