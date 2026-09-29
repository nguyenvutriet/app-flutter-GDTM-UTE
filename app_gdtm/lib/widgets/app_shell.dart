import 'package:flutter/material.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/app_menu.dart';

/// Khung dùng chung: Header + Menu + phần nội dung [child].
///  - Laptop/tablet ngang (>= [desktopBreakpoint]): menu hiện sẵn bên trái,
///    nút ☰ dùng để thu gọn / mở lại menu.
///  - Di động: menu ẩn, bấm ☰ để mở Drawer.
class AppShell extends StatefulWidget {
  final List<AppMenuSection> sections;
  final List<AppMenuItem> footerItems;
  final String selectedMenuId;
  final ValueChanged<String> onMenuSelected;
  final Widget child;

  const AppShell({
    super.key,
    required this.sections,
    this.footerItems = const [],
    required this.selectedMenuId,
    required this.onMenuSelected,
    required this.child,
  });

  static const double desktopBreakpoint = 900;
  static const double sidebarWidth = 280;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarOpen = true; // chỉ dùng cho laptop

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= AppShell.desktopBreakpoint;

    final menu = AppMenu(
      sections: widget.sections,
      footerItems: widget.footerItems,
      selectedId: widget.selectedMenuId,
      onSelected: (id) {
        if (!isDesktop) Navigator.of(context).maybePop(); // đóng Drawer
        widget.onMenuSelected(id);
      },
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.pageBg,
      drawer: isDesktop
          ? null
          : Drawer(
              width: AppShell.sidebarWidth,
              backgroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(),
              child: menu,
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  onMenuPressed: () {
                    if (isDesktop) {
                      setState(() => _sidebarOpen = !_sidebarOpen);
                    } else {
                      _scaffoldKey.currentState?.openDrawer();
                    }
                  },
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header xanh: ☰ | (trống) | cờ VN, chuông thông báo, avatar.
class AppHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final int notificationCount;

  const AppHeader({
    super.key,
    required this.onMenuPressed,
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onMenuPressed,
                  icon: const Icon(Icons.menu, color: Colors.white),
                ),
                const Spacer(),
                // Cờ Việt Nam
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
                // Chuông + badge
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
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
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: AppColors.primary),
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