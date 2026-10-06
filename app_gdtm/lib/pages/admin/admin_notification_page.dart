// lib/pages/admin/admin_notification_page.dart
// Thông báo hệ thống của admin (realtime): có người báo cáo bài viết / bình luận.
// - Chạm vào thông báo: đánh dấu đã đọc + mở trang xử lý tương ứng (qua [onOpenReport]).
// - Vuốt sang trái để xóa; menu ⋯ để đánh dấu đã đọc / chưa đọc.
import 'package:flutter/material.dart';

import 'package:app_gdtm/services/admin_notification_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart'; // kFbBg, kFbBlue, kFbText2, timeAgo
import 'package:app_gdtm/widgets/page_title.dart';

class AdminNotificationPage extends StatefulWidget {
  final AdminNotificationService service;

  /// Mở trang xử lý báo cáo tương ứng (bài viết / bình luận vi phạm)
  final ValueChanged<AdminNotification> onOpenReport;

  const AdminNotificationPage({
    super.key,
    required this.service,
    required this.onOpenReport,
  });

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  static const _orange = Color(0xFFE37400);
  static const _red = Color(0xFFD93025);

  bool _onlyUnread = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  void _open(AdminNotification n) {
    if (!n.isRead) _run(() => widget.service.setRead(n.id, true));
    widget.onOpenReport(n);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kFbBg,
      child: StreamBuilder<List<AdminNotification>>(
        stream: widget.service.watch(),
        builder: (context, snap) {
          final all = snap.data ?? const <AdminNotification>[];
          final unread = all.where((n) => !n.isRead).length;
          final items = _onlyUnread ? all.where((n) => !n.isRead).toList() : all;

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 700;
            return ListView(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 12, wide ? 24 : 12, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PageTitle('THÔNG BÁO'),
                        const SizedBox(height: 12),
                        _toolbar(unread),
                        const SizedBox(height: 8),
                        if (snap.hasError)
                          _message('Không thể tải thông báo: ${snap.error}', error: true)
                        else if (!snap.hasData)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (items.isEmpty)
                          _message(_onlyUnread
                              ? 'Không có thông báo chưa đọc'
                              : 'Chưa có thông báo nào')
                        else
                          for (final n in items) _tile(n),
                      ],
                    ),
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }

  Widget _toolbar(int unread) => Row(children: [
        ChoiceChip(
          label: const Text('Tất cả'),
          selected: !_onlyUnread,
          selectedColor: const Color(0xFFE7F3FF),
          labelStyle: TextStyle(
            color: !_onlyUnread ? kFbBlue : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => _onlyUnread = false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('Chưa đọc${unread > 0 ? ' ($unread)' : ''}'),
          selected: _onlyUnread,
          selectedColor: const Color(0xFFE7F3FF),
          labelStyle: TextStyle(
            color: _onlyUnread ? kFbBlue : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => _onlyUnread = true),
        ),
        const Spacer(),
        if (unread > 0)
          TextButton(
            onPressed: () => _run(widget.service.markAllRead),
            child: const Text('Đọc tất cả'),
          ),
      ]);

  Widget _message(String text, {bool error = false}) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: error ? Colors.red : kFbText2),
          ),
        ),
      );

  Widget _tile(AdminNotification n) {
    final color = n.isPostReport ? _orange : _red;
    final icon = n.isPostReport ? Icons.flag : Icons.chat_bubble_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: _red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _run(() => widget.service.delete(n.id)),
          child: Material(
            color: n.isRead ? Colors.white : const Color(0xFFE7F3FF),
            child: InkWell(
              onTap: () => _open(n),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeAgo(n.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: n.isRead ? kFbText2 : kFbBlue,
                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                  Column(children: [
                    if (!n.isRead)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 6),
                        child: Icon(Icons.circle, size: 10, color: kFbBlue),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: kFbText2),
                      tooltip: 'Tùy chọn',
                      onSelected: (v) {
                        if (v == 'toggle') {
                          _run(() => widget.service.setRead(n.id, !n.isRead));
                        }
                        if (v == 'delete') _run(() => widget.service.delete(n.id));
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(n.isRead ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa thông báo', style: TextStyle(color: _red)),
                        ),
                      ],
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
