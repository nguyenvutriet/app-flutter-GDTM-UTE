import 'package:flutter/material.dart';
import 'package:app_gdtm/models/Notification.dart' as app_notification;
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/pages/student/feedback_detail_page.dart';
import 'package:app_gdtm/pages/student/post_detail_page.dart';
import 'package:app_gdtm/services/NotificationService.dart';
import 'package:app_gdtm/services/RequestService.dart' as request_service;
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

class NotificationPage extends StatefulWidget {
  final Users user;
  final app_notification.Notification? initialNotification;
  final ValueChanged<Request>? onOpenFeedback;
  final ValueChanged<app_notification.Notification>? onReadChanged;

  const NotificationPage({
    super.key,
    required this.user,
    this.initialNotification,
    this.onOpenFeedback,
    this.onReadChanged,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _readTab = 0;
  int _typeTab = 0;
  final _service = NotificationService();
  late Future<List<app_notification.Notification>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _loadNotifications();
    _openInitialNotification();
  }

  @override
  void didUpdateWidget(covariant NotificationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.initialNotification?.id;
    final newId = widget.initialNotification?.id;
    if (newId != null && newId != oldId) {
      _openInitialNotification();
    }
  }

  void _openInitialNotification() {
    final notification = widget.initialNotification;
    if (notification == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(notification);
    });
  }

  Future<List<app_notification.Notification>> _loadNotifications() async {
    final role = UserRoleX.fromString(widget.user.role);
    final canReceiveDepartmentNotifications =
        role == UserRole.staff || role == UserRole.admin;

    final notifications = await _service.getNotifications(
      userId: canReceiveDepartmentNotifications ? null : widget.user.id,
      departmentId: canReceiveDepartmentNotifications
          ? widget.user.departmentId
          : null,
    );

    final filtered = <app_notification.Notification>[];
    for (final notification in notifications) {
      final matchesReadFilter =
          _readTab == 0 ||
          (_readTab == 1 && notification.isRead != true) ||
          (_readTab == 2 && notification.isRead == true);
      if (!matchesReadFilter) continue;

      if (_typeTab == 0) {
        filtered.add(notification);
        continue;
      }

      final requestId = notification.requestId;
      if (requestId == null || requestId.isEmpty) continue;
      final request = await _service.getRequestById(requestId);
      if (request == null) continue;

      final isForumPost =
          request.postStatus == request_service.RequestService.postStatusPublic;
      final matchesType = _typeTab == 1 ? isForumPost : !isForumPost;
      if (matchesType) filtered.add(notification);
    }
    return filtered;
  }

  Future<void> _reload() async {
    setState(() => _notifications = _loadNotifications());
  }

  Future<void> _markRead(app_notification.Notification notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty || notification.isRead == true) return;
    await _service.setNotificationRead(id, true);
    if (!mounted) return;
    setState(() => notification.isRead = true);
    widget.onReadChanged?.call(notification);
  }

  Future<void> _toggleRead(app_notification.Notification notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty) return;
    final isRead = notification.isRead != true;
    await _service.setNotificationRead(id, isRead);
    if (!mounted) return;
    setState(() => notification.isRead = isRead);
    widget.onReadChanged?.call(notification);
  }

  Future<void> _delete(app_notification.Notification notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty) return;
    await _service.deleteNotification(id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _open(app_notification.Notification notification) async {
    await _markRead(notification);
    final requestId = notification.requestId;
    if (requestId == null || requestId.isEmpty || !mounted) return;

    final request = await _service.getRequestById(requestId);
    if (!mounted || request == null) return;

    if (request.postStatus == request_service.RequestService.postStatusPublic) {
      final forum = ForumService(currentUserId: () => widget.user.id);
      final post = await forum.getPostDetail(requestId);
      if (!mounted || post == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(initialPost: post, service: forum),
        ),
      );
      return;
    }

    if (widget.onOpenFeedback != null) {
      widget.onOpenFeedback!(request);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackDetailPage(
          request: request,
          user: widget.user,
          departments: const [],
          categories: const [],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return FutureBuilder<List<app_notification.Notification>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Không thể tải thông báo: ${snapshot.error}'),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Chưa có thông báo'));
        }
        return Column(
          children: items
              .map(
                (item) => _NotificationTile(
                  notification: item,
                  onTap: () => _open(item),
                  onToggleRead: () => _toggleRead(item),
                  onDelete: () => _delete(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 700;
        final pad = wide ? 32.0 : 14.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageTitle('THÔNG BÁO'),
              const SizedBox(height: 16),
              Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Expanded(
                      child: _Tabs(
                        index: _readTab,
                        labels: const ['TẤT CẢ', 'CHƯA XEM', 'ĐÃ XEM'],
                        onChanged: (i) => setState(() {
                          _readTab = i;
                          _notifications = _loadNotifications();
                        }),
                      ),
                    )
                  else
                    _Tabs(
                      index: _readTab,
                      labels: const ['TẤT CẢ', 'CHƯA XEM', 'ĐÃ XEM'],
                      onChanged: (i) => setState(() {
                        _readTab = i;
                        _notifications = _loadNotifications();
                      }),
                    ),
                  SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
                  SizedBox(
                    width: wide ? 190 : double.infinity,
                    child: DropdownButtonFormField<int>(
                      initialValue: _typeTab,
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Tất cả')),
                        DropdownMenuItem(value: 1, child: Text('Diễn đàn')),
                        DropdownMenuItem(value: 2, child: Text('Góp ý')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _typeTab = value;
                          _notifications = _loadNotifications();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTabContent(),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final app_notification.Notification notification;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onToggleRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final unread = notification.isRead != true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: unread ? Colors.blue.shade50 : Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          unread ? Icons.notifications_active : Icons.notifications_none,
          color: unread ? AppColors.primary : Colors.grey,
        ),
        title: Text(
          notification.title ?? 'Thông báo',
          style: TextStyle(fontWeight: unread ? FontWeight.bold : null),
        ),
        subtitle: Text(notification.content ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: unread ? 'Đánh dấu đã đọc' : 'Bỏ đánh dấu đã đọc',
              icon: Icon(
                unread ? Icons.mark_email_read : Icons.mark_email_unread,
              ),
              onPressed: onToggleRead,
            ),
            IconButton(
              tooltip: 'Xóa thông báo',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn "THÔNG BÁO" có tam giác xám bên phải, đường kẻ dưới chạy hết chiều ngang.
class _PageTitle extends StatelessWidget {
  final String text;
  const _PageTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // kéo đường kẻ sang hết bên kia
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black26, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          CustomPaint(size: const Size(20, 40), painter: _TrianglePainter()),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.grey.shade600);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hàng tab, đường kẻ dưới chạy hết chiều ngang.
class _Tabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // kéo đường kẻ sang hết bên kia
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Wrap(
        children: [
          for (int i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == index ? AppColors.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: i == index ? AppColors.primary : Colors.black45,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
