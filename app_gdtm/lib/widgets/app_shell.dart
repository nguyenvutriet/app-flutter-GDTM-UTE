import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Notification.dart' as app_notification;
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/services/NotificationService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/app_menu.dart';

/// Khung dùng chung: Header + Menu + phần nội dung [child].
///
/// - Laptop/tablet ngang (>= [desktopBreakpoint]):
///   menu hiện sẵn bên trái,
///   nút ☰ dùng để thu gọn / mở lại menu.
///
/// - Di động:
///   menu ẩn,
///   bấm ☰ để mở Drawer.
class AppShell extends StatefulWidget {
  final List<AppMenuSection> sections;
  final List<AppMenuItem> footerItems;
  final String selectedMenuId;
  final ValueChanged<String> onMenuSelected;
  final Widget child;
  final ValueChanged<app_notification.Notification>? onNotificationSelected;
  final ValueNotifier<app_notification.Notification?>? notificationReadNotifier;
    /// Chuông thông báo tùy chỉnh (admin). Null = dùng chuông mặc định.
  final Widget? notificationBell;

  /// Người dùng đang đăng nhập.
  final Users user;

  const AppShell({
    super.key,
    required this.sections,
    this.footerItems = const [],
    required this.selectedMenuId,
    required this.onMenuSelected,
    required this.child,
    required this.user,
    this.onNotificationSelected,
    this.notificationReadNotifier,
    this.notificationBell,
  });

  static const double desktopBreakpoint = 900;
  static const double sidebarWidth = 280;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Chỉ sử dụng cho laptop/tablet ngang.
  bool _sidebarOpen = true;
  int _notificationCount = 0;
  List<app_notification.Notification> _unreadNotifications = [];
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    widget.notificationReadNotifier?.addListener(_onNotificationReadChanged);
    _loadNotificationCount();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationReadNotifier != widget.notificationReadNotifier) {
      oldWidget.notificationReadNotifier?.removeListener(
        _onNotificationReadChanged,
      );
      widget.notificationReadNotifier?.addListener(_onNotificationReadChanged);
    }
  }

  @override
  void dispose() {
    widget.notificationReadNotifier?.removeListener(_onNotificationReadChanged);
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    final role = UserRoleX.fromString(widget.user.role);
    final isDepartmentUser = role == UserRole.staff || role == UserRole.admin;
    final notifications = await _notificationService.getNotifications(
      userId: isDepartmentUser ? null : widget.user.id,
      departmentId: isDepartmentUser ? widget.user.departmentId : null,
    );
    final unread = notifications
        .where((notification) => notification.isRead != true)
        .toList();
    if (!mounted) return;
    setState(() {
      _unreadNotifications = unread;
      _notificationCount = unread.length;
    });
  }

  void _onNotificationReadChanged() {
    final notification = widget.notificationReadNotifier?.value;
    if (notification == null || !mounted) return;
    setState(() {
      if (notification.isRead == true) {
        _unreadNotifications = _unreadNotifications
            .where((item) => item.id != notification.id)
            .toList();
      } else if (!_unreadNotifications.any(
        (item) => item.id == notification.id,
      )) {
        _unreadNotifications = [..._unreadNotifications, notification];
      }
      _notificationCount = _unreadNotifications.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= AppShell.desktopBreakpoint;

    // ============================================================
    // MENU
    // ============================================================

    final menu = AppMenu(
      sections: widget.sections,
      footerItems: widget.footerItems,
      selectedId: widget.selectedMenuId,

      // Người dùng đang đăng nhập
      user: widget.user,

      onSelected: (id) {
        // Nếu đang dùng Drawer trên điện thoại
        // thì đóng Drawer trước.
        if (!isDesktop) {
          Navigator.of(context).maybePop();
        }

        widget.onMenuSelected(id);
      },
    );

    // ============================================================
    // GIAO DIỆN
    // ============================================================

    return Scaffold(
      key: _scaffoldKey,

      backgroundColor: AppColors.pageBg,

      // ==========================================================
      // DRAWER - MOBILE
      // ==========================================================
      drawer: isDesktop
          ? null
          : Drawer(
              width: AppShell.sidebarWidth,
              backgroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(),
              child: menu,
            ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ========================================================
          // SIDEBAR - DESKTOP
          // ========================================================

          if (isDesktop)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),

              width: _sidebarOpen ? AppShell.sidebarWidth : 0,

              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,

                  minWidth: AppShell.sidebarWidth,
                  maxWidth: AppShell.sidebarWidth,

                  child: menu,
                ),
              ),
            ),

          // ========================================================
          // NỘI DUNG CHÍNH
          // ========================================================
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Flutter Web can briefly report a 1x1 viewport while the
                // browser is attaching the view. Avoid laying out the fixed
                // header in that transient space.
                if (constraints.maxHeight < 60) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    // --------------------------------------------------
                    // HEADER
                    // --------------------------------------------------

                    AppHeader(
                      user: widget.user,
                      notificationCount: _notificationCount,
                      unreadNotifications: _unreadNotifications,
                      notificationBell: widget.notificationBell,
                      onNotificationSelected:
                          widget.onNotificationSelected == null
                          ? null
                          : (notification) async {
                              final id = notification.id;
                              if (id == null || id.isEmpty) return;
                              setState(() {
                                _unreadNotifications = _unreadNotifications
                                    .where((item) => item.id != id)
                                    .toList();
                                _notificationCount =
                                    _unreadNotifications.length;
                              });
                              widget.onNotificationSelected!(notification);
                              await _notificationService.setNotificationRead(
                                id,
                                true,
                              );
                            },

                      onMenuPressed: () {
                        if (isDesktop) {
                          // Laptop:
                          // mở / đóng sidebar
                          setState(() {
                            _sidebarOpen = !_sidebarOpen;
                          });
                        } else {
                          // Mobile:
                          // mở Drawer
                          _scaffoldKey.currentState?.openDrawer();
                        }
                      },
                    ),

                    // --------------------------------------------------
                    // PAGE CONTENT
                    // --------------------------------------------------
                    Expanded(child: widget.child),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ================================================================
/// HEADER
/// ================================================================
///
/// Header xanh:
/// ☰ | khoảng trống | cờ VN | chuông | avatar
///
/// Avatar hiện tại vẫn dùng icon mặc định.
/// Sau này nếu Users có avatarUrl thì có thể đổi sang ảnh thật.
class AppHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;

  /// Số lượng thông báo chưa đọc.
  final int notificationCount;

  /// Người dùng đang đăng nhập.
  final Users user;
  final List<app_notification.Notification> unreadNotifications;
  final ValueChanged<app_notification.Notification>? onNotificationSelected;
  final Widget? notificationBell;

  const AppHeader({
    super.key,
    required this.onMenuPressed,
    required this.user,
    this.unreadNotifications = const [],
    this.onNotificationSelected,
    this.notificationCount = 0,
    this.notificationBell,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 3,

      child: SafeArea(
        bottom: false,

        child: SizedBox(
          height: 60,

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),

            child: Row(
              children: [
                // ==================================================
                // MENU BUTTON
                // ==================================================

                IconButton(
                  onPressed: onMenuPressed,

                  icon: const Icon(Icons.menu, color: Colors.white),
                ),

                const Spacer(),

                // ==================================================
                // CỜ VIỆT NAM
                // ==================================================
                Container(
                  width: 22,
                  height: 15,

                  color: const Color(0xFFDA251D),

                  alignment: Alignment.center,

                  child: const Icon(
                    Icons.star,
                    size: 11,
                    color: Color(0xFFFFFF00),
                  ),
                ),

                const SizedBox(width: 12),

                // ==================================================
                // THÔNG BÁO
                // ==================================================
                notificationBell ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<app_notification.Notification>(
                      onSelected: onNotificationSelected,
                      tooltip: 'Thông báo chưa xem',
                      color: Colors.white,
                      itemBuilder: (context) {
                        if (unreadNotifications.isEmpty) {
                          return const [
                            PopupMenuItem(
                              enabled: false,
                              child: Text('Không có thông báo mới'),
                            ),
                          ];
                        }
                        return unreadNotifications
                            .take(6)
                            .map(
                              (notification) =>
                                  PopupMenuItem<app_notification.Notification>(
                                    value: notification,
                                    child: SizedBox(
                                      width: 300,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.notifications_active,
                                          color: AppColors.primary,
                                        ),
                                        title: Text(
                                          notification.title ?? 'Thông báo',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          notification.content ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                            )
                            .toList();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                          if (notificationCount > 0)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (notificationCount > 0)
                      Text(
                        '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),

                const SizedBox(width: 4),

                // ==================================================
                // AVATAR
                // ==================================================
                Tooltip(
                  message: user.fullName ?? 'Người dùng',

                  child: const CircleAvatar(
                    radius: 17,

                    backgroundColor: Colors.white,

                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
