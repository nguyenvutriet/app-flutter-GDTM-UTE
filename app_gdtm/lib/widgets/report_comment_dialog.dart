// lib/widgets/report_comment_dialog.dart
// Hộp thoại "Báo cáo bình luận" (giống Facebook): chọn lý do rồi gửi.
// Mỗi người chỉ báo cáo 1 bình luận được 1 lần (ForumService.reportComment kiểm tra).
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

/// Trả về true nếu bình luận đã được báo cáo (vừa gửi xong hoặc đã báo cáo từ trước).
Future<bool> showReportCommentDialog(
  BuildContext context, {
  required ForumService service,
  required CommentDTO comment,
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
        title: const Text('Báo cáo bình luận'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bình luận của ${comment.userName}',
                    style: const TextStyle(color: kFbText2, fontSize: 13)),
                const SizedBox(height: 4),
                Text(comment.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                const Text('Vì sao bạn báo cáo bình luận này?',
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
                      await service.reportComment(comment.id, reason);
                      done = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Đã gửi báo cáo. Cảm ơn bạn!')));
                    } catch (e) {
                      // Gồm cả lỗi "Bạn đã báo cáo bình luận này rồi"
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