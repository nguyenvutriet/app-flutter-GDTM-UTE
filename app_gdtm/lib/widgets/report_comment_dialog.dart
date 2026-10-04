// lib/widgets/report_comment_dialog.dart
// Hộp thoại báo cáo (giống Facebook): chọn lý do rồi gửi. Dùng cho cả bình luận và bài viết.
// Mỗi người chỉ báo cáo 1 bình luận / 1 bài viết được 1 lần (ForumService kiểm tra).
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';

const List<String> kReportReasons = [
  'Ngôn ngữ thô tục, xúc phạm',
  'Spam hoặc quảng cáo',
  'Thông tin sai lệch, bịa đặt',
  'Nội dung không phù hợp',
  'Khác',
];

/// Báo cáo một bình luận.
/// Trả về true nếu đã báo cáo (vừa gửi xong hoặc đã báo cáo từ trước).
Future<bool> showReportCommentDialog(
  BuildContext context, {
  required ForumService service,
  required CommentDTO comment,
}) =>
    showReportDialog(
      context,
      title: 'Báo cáo bình luận',
      subtitle: 'Bình luận của ${comment.userName}',
      preview: comment.content,
      onSubmit: (reason) => service.reportComment(comment.id, reason),
    );

/// Báo cáo một bài viết.
/// Trả về true nếu đã báo cáo (vừa gửi xong hoặc đã báo cáo từ trước).
Future<bool> showReportPostDialog(
  BuildContext context, {
  required ForumService service,
  required ForumPostDTO post,
}) =>
    showReportDialog(
      context,
      title: 'Báo cáo bài viết',
      subtitle: 'Bài viết của ${post.userName}',
      preview: post.subject,
      onSubmit: (reason) => service.reportPost(post.id, reason),
    );

/// Hộp thoại chọn lý do dùng chung.
Future<bool> showReportDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String preview,
  required Future<void> Function(String reason) onSubmit,
}) async {
  const other = 'Khác';
  String? selected;
  final otherCtl = TextEditingController();
  bool sending = false;
  bool done = false;
  String? error;

  final messenger = ScaffoldMessenger.of(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: const TextStyle(color: kFbText2, fontSize: 13)),
                const SizedBox(height: 4),
                Text(preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                const Text('Vì sao bạn báo cáo?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final r in kReportReasons)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r),
                    value: r,
                    groupValue: selected,
                    onChanged: sending
                        ? null
                        : (v) => setD(() {
                              selected = v;
                              error = null;
                            }),
                  ),
                if (selected == other)
                  TextField(
                    controller: otherCtl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: 'Mô tả lý do...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: sending ? null : () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kFbBlue),
            onPressed: sending
                ? null
                : () async {
                    if (selected == null) {
                      setD(() => error = 'Vui lòng chọn lý do');
                      return;
                    }
                    var reason = selected!;
                    if (selected == other) {
                      final t = otherCtl.text.trim();
                      if (t.isEmpty) {
                        setD(() => error = 'Vui lòng mô tả lý do');
                        return;
                      }
                      reason = t;
                    }
                    setD(() {
                      sending = true;
                      error = null;
                    });
                    try {
                      await onSubmit(reason);
                      done = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Đã gửi báo cáo. Cảm ơn bạn!')));
                    } catch (e) {
                      // Đã báo cáo từ trước (vd. ở thiết bị khác) thì cũng coi là đã báo cáo
                      if (e.toString().contains('đã báo cáo')) done = true;
                      setD(() {
                        sending = false;
                        error = e.toString();
                      });
                    }
                  },
            child: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Gửi báo cáo'),
          ),
        ],
      ),
    ),
  );
  otherCtl.dispose();
  return done;
}