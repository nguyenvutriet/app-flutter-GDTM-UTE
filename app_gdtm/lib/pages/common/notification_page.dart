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
import 'package:app_gdtm/widgets/forum_utils.dart'; // kFbBg, kFbBlue, kFbText2
import 'package:app_gdtm/widgets/page_title.dart';

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
  static const _red = Color(0xFFD93025);

  int _readTab = 0; // 0 tất cả, 1 chưa xem, 2 đã xem
  int _typeTab = 0; // 0 tất cả, 1 diễn đàn, 2 góp ý
  final _service = NotificationService();

  List<app_notification.Notification> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _loadNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
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
    try {
      await _service.setNotificationRead(id, isRead);
    } catch (e) {
      _toast('Lỗi: $e');
      return;
    }
    if (!mounted) return;
    setState(() => notification.isRead = isRead);
    widget.onReadChanged?.call(notification);
  }

  Future<void> _delete(app_notification.Notification notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty) return;

    // Xóa khỏi giao diện ngay (Dismissible bắt buộc phải gỡ item tức thì)
    setState(() => _items.remove(notification));

    // Thông báo chưa đọc bị xóa thì cập nhật lại số trên header
    if (notification.isRead != true) {
      notification.isRead = true;
      widget.onReadChanged?.call(notification);
    }

    try {
      await _service.deleteNotification(id);
    } catch (e) {
      _toast('Lỗi: $e');
      _reload();
    }
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

  // ============================================================
  // GIAO DIỆN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kFbBg,
      child: LayoutBuilder(
        builder: (context, c) {
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
                      _filters(wide),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        _message('Không thể tải thông báo: $_error', error: true)
                      else if (_items.isEmpty)
                        _message('Chưa có thông báo')
                      else
                        for (final n in _items) _tile(n),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Bộ lọc: tab TẤT CẢ / CHƯA XEM / ĐÃ XEM + dropdown "Lọc theo".
  Widget _filters(bool wide) {
    final tabs = _Tabs(
      index: _readTab,
      labels: const ['TẤT CẢ', 'CHƯA XEM', 'ĐÃ XEM'],
      onChanged: (i) {
        _readTab = i;
        _reload();
      },
    );

    final dropdown = SizedBox(
      width: wide ? 190 : double.infinity,
      child: DropdownButtonFormField<int>(
        initialValue: _typeTab,
        decoration: const InputDecoration(
          labelText: 'Lọc theo',
          border: OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Tất cả')),
          DropdownMenuItem(value: 1, child: Text('Diễn đàn')),
          DropdownMenuItem(value: 2, child: Text('Góp ý')),
        ],
        onChanged: (value) {
          if (value == null) return;
          _typeTab = value;
          _reload();
        },
      ),
    );

    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide) Expanded(child: tabs) else tabs,
        SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
        dropdown,
      ],
    );
  }

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

  Widget _tile(app_notification.Notification n) {
    final unread = n.isRead != true;
    final color = unread ? AppColors.primary : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Dismissible(
          key: ValueKey(n.id ?? n.hashCode),
          direction: DismissDirection.endToStart,
          background: Container(
            color: _red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(n),
          child: Material(
            color: unread ? const Color(0xFFE7F3FF) : Colors.white,
            child: InkWell(
              onTap: () => _open(n),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(
                        unread
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title ?? 'Thông báo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.content ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    Column(children: [
                      if (unread)
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 6),
                          child: Icon(Icons.circle, size: 10, color: kFbBlue),
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            size: 20, color: kFbText2),
                        tooltip: 'Tùy chọn',
                        onSelected: (v) {
                          if (v == 'toggle') _toggleRead(n);
                          if (v == 'delete') _delete(n);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(unread
                                ? 'Đánh dấu đã đọc'
                                : 'Đánh dấu chưa đọc'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa thông báo',
                                style: TextStyle(color: _red)),
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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