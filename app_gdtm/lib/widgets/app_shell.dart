import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Users.dart';
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
  });

  static const double desktopBreakpoint = 900;
  static const double sidebarWidth = 280;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  /// Chỉ sử dụng cho laptop/tablet ngang.
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >=
            AppShell.desktopBreakpoint;

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
              duration: const Duration(
                milliseconds: 200,
              ),

              width: _sidebarOpen
                  ? AppShell.sidebarWidth
                  : 0,

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
            child: Column(
              children: [
                // --------------------------------------------------
                // HEADER
                // --------------------------------------------------

                AppHeader(
                  user: widget.user,

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

                Expanded(
                  child: widget.child,
                ),
              ],
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

  const AppHeader({
    super.key,
    required this.onMenuPressed,
    required this.user,
    this.notificationCount = 7,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),

            child: Row(
              children: [
                // ==================================================
                // MENU BUTTON
                // ==================================================

                IconButton(
                  onPressed: onMenuPressed,

                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                  ),
                ),

                const Spacer(),

                // ==================================================
                // CỜ VIỆT NAM
                // ==================================================

                Container(
                  width: 22,
                  height: 15,

                  color: const Color(
                    0xFFDA251D,
                  ),

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

                Stack(
                  clipBehavior: Clip.none,

                  children: [
                    IconButton(
                      onPressed: () {},

                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                    ),

                    if (notificationCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,

                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),

                          child: Text(
                            '$notificationCount',

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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

                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                    ),
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