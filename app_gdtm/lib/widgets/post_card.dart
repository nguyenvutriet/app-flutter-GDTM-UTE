// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'forum_utils.dart';
import 'reaction_button.dart';

class PostCard extends StatelessWidget {
  final ForumPostDTO post;
  final ValueChanged<String> onReact;

  /// Mở trang chi tiết (ở trang chi tiết thì để null)
  final VoidCallback? onOpen;

  /// Bấm nút "Bình luận" (mặc định = onOpen)
  final VoidCallback? onTapComments;

  /// true = hiển thị đầy đủ nội dung (trang chi tiết)
  final bool expanded;

  const PostCard({
    super.key,
    required this.post,
    required this.onReact,
    this.onOpen,
    this.onTapComments,
    this.expanded = false,
  });

  bool _isImage(AttachmentDTO a) {
    final t = a.fileType.toLowerCase();
    final u = a.fileUrl.toLowerCase().split('?').first;
    const exts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    return t.contains('image') || exts.any((e) => t == e || u.endsWith('.$e'));
  }

  @override
  Widget build(BuildContext context) {
    final images = post.attachments.where(_isImage).toList();
    final files = post.attachments.where((a) => !_isImage(a)).toList();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            InitialAvatar(name: post.userName, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(
                    child: Text(
                      '${post.departmentName} · ${timeAgo(post.date)} · ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kFbText2, fontSize: 12.5),
                    ),
                  ),
                  const Icon(Icons.public, size: 13, color: kFbText2),
                ]),
              ]),
            ),
          ]),
        ),

        // Nội dung
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(post.description,
                    maxLines: expanded ? null : 5,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.35)),
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
              ReactionSummary(emojis: post.topReactionIcons, total: post.totalReactions),
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
        ]),
      ]),
    );
  }
}