// lib/widgets/comment_tile.dart
// Bình luận kiểu Facebook: bong bóng xám, Thích · Phản hồi · Xóa, reply thụt lề.
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

  const CommentTile({
    super.key,
    required this.comment,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = comment;
    // Chỉ hiện @tên khi trả lời một reply (không phải bình luận gốc)
    final showMention =
        c.isReply && c.replyToUsername != null && c.replyId != c.parentId;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InitialAvatar(name: c.userName, radius: isReply ? 14 : 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kFbBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(c.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      if (c.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: kFbBlue),
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
              ),
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
                    if (c.canDelete)
                      GestureDetector(
                        onTap: () => onDelete(c),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Xóa',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kFbText2)),
                        ),
                      ),
                    ReactionSummary(
                      emojis: topReactionEmojis(c.reactions),
                      total: c.totalReactions,
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
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
                    ))
                .toList(),
          ),
        ),
    ]);
  }
}