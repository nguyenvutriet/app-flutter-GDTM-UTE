// lib/widgets/admin_notification_bell.dart
// Chuông thông báo của admin trên header:
//  - bubble đỏ hiện số thông báo chưa đọc (realtime, "99+" nếu quá 99);
//  - bấm vào mở bảng "Các thông báo" ngay dưới chuông (danh sách realtime, nút đánh dấu
//    tất cả đã đọc, nút "Xem tất cả" sang trang Thông báo).
import 'package:flutter/material.dart';

import 'package:app_gdtm/services/admin_notification_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart'; // kFbBlue, kFbText2, timeAgo

class AdminNotificationBell extends StatelessWidget {
  final AdminNotificationService service;

  /// Bấm vào một thông báo trong bảng: mở bài viết / bình luận bị báo cáo
  final ValueChanged<AdminNotification> onOpenReport;

  /// Bấm "Xem tất cả": chuyển sang trang Thông báo
  final VoidCallback onSeeAll;

  /// Màu biểu tượng chuông (header xanh nên mặc định trắng)
  final Color iconColor;

  const AdminNotificationBell({
    super.key,
    required this.service,
    required this.onOpenReport,
    required this.onSeeAll,
    this.iconColor = Colors.white,
  });

  void _openPanel(BuildContext bellContext) {
    final box = bellContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.of(bellContext).size;

    final panelW = (screen.width - 16).clamp(0.0, 380.0);
    final top = origin.dy + size.height + 4;
    final left = (origin.dx + size.width - panelW).clamp(8.0, screen.width - panelW - 8);
    final maxH = (screen.height - top - 16).clamp(220.0, 520.0);

    showGeneralDialog<void>(
      context: bellContext,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 120),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (dialogContext, _, __) => Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: panelW,
          child: Material(
            elevation: 10,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: _Panel(
                service: service,
                onOpen: (n) {
                  Navigator.of(dialogContext).pop();
                  if (!n.isRead) service.setRead(n.id, true).catchError((_) {});
                  onOpenReport(n);
                },
                onSeeAll: () {
                  Navigator.of(dialogContext).pop();
                  onSeeAll();
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: service.watchUnreadCount(),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return Builder(
          builder: (bellContext) => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () => _openPanel(bellContext),
                icon: Icon(Icons.notifications_none, color: iconColor),
              ),
              if (n > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text(
                        n > 99 ? '99+' : '$n',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  static const _orange = Color(0xFFE37400);
  static const _red = Color(0xFFD93025);

  final AdminNotificationService service;
  final ValueChanged<AdminNotification> onOpen;
  final VoidCallback onSeeAll;

  const _Panel({
    required this.service,
    required this.onOpen,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminNotification>>(
      stream: service.watch(limit: 30),
      builder: (context, snap) {
        final items = snap.data ?? const <AdminNotification>[];
        final unread = items.where((n) => !n.isRead).length;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          // ---- Tiêu đề ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(children: [
              const Expanded(
                child: Text('Các thông báo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'Đánh dấu tất cả đã đọc',
                icon: Icon(Icons.done_all, color: unread > 0 ? kFbBlue : Colors.black26),
                onPressed: unread > 0
                    ? () => service.markAllRead().catchError((_) {})
                    : null,
              ),
            ]),
          ),
          const Divider(height: 1),

          // ---- Danh sách ----
          Flexible(
            child: snap.hasError
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không thể tải thông báo',
                        style: TextStyle(color: Colors.red)),
                  )
                : !snap.hasData
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Chưa có thông báo nào',
                                style: TextStyle(color: kFbText2)),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _item(items[i]),
                          ),
          ),

          // ---- Chân ----
          const Divider(height: 1),
          InkWell(
            onTap: onSeeAll,
            child: const SizedBox(
              height: 44,
              width: double.infinity,
              child: Center(
                child: Text('Xem tất cả',
                    style: TextStyle(color: kFbBlue, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _item(AdminNotification n) {
    final color = n.isPostReport ? _orange : _red;
    final icon = n.isPostReport ? Icons.flag : Icons.chat_bubble_outline;
    return InkWell(
      onTap: () => onOpen(n),
      child: Container(
        color: n.isRead ? Colors.white : const Color(0xFFEAF2FF),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                n.title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                n.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(timeAgo(n.createdAt),
                  style: const TextStyle(fontSize: 12, color: kFbText2)),
            ]),
          ),
          if (!n.isRead)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 6),
              child: Icon(Icons.circle, size: 9, color: kFbBlue),
            ),
        ]),
      ),
    );
  }
}