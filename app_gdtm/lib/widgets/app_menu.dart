import 'package:flutter/material.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

/// Một mục trong menu bên trái.
class AppMenuItem {
  final String id;
  final String title;
  final IconData icon;

  const AppMenuItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// Một nhóm menu (có tiêu đề màu vàng).
class AppMenuSection {
  final String title;
  final List<AppMenuItem> items;

  const AppMenuSection({required this.title, required this.items});
}

/// Menu bên trái: dùng làm Drawer (di động) hoặc sidebar cố định (laptop).
class AppMenu extends StatelessWidget {
  final List<AppMenuSection> sections;
  final List<AppMenuItem> footerItems;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const AppMenu({
    super.key,
    required this.sections,
    this.footerItems = const [],
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Image.asset('lib/assets/ute_logo.png', height: 120),
            ),
            const Divider(color: Colors.white24, height: 1),
            // Thông tin sinh viên
            const _StudentInfo(),
            const Divider(color: Colors.white24, height: 1),
            // Danh sách menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          color: AppColors.menuSection,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    for (final item in section.items)
                      _MenuTile(
                        item: item,
                        selected: item.id == selectedId,
                        onTap: () => onSelected(item.id),
                      ),
                  ],
                ],
              ),
            ),
                        const Divider(color: Colors.white24, height: 1),
            for (final item in footerItems)
              _MenuTile(
                item: item,
                selected: item.id == selectedId,
                onTap: () => onSelected(item.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StudentInfo extends StatelessWidget {
  const _StudentInfo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: AppColors.primary, size: 30),
            // Có ảnh thật: backgroundImage: NetworkImage(url)
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Võ Thị Mai Quỳnh',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'SV/HV/NCS - 23110147',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '(Còn học)',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final AppMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MenuTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.menuActive : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            // Thanh nhấn bên trái khi đang chọn
            Container(
              width: 4,
              height: 28,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A237E), AppColors.menuActive],
                      )
                    : null,
              ),
            ),
            Icon(item.icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}