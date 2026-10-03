import 'package:flutter/material.dart';

import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/pages/common/announcement_detail_page.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/widgets/announcement_card.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

class DepartmentAnnouncementsPage extends StatefulWidget {
  final AnnouncementService service;

  const DepartmentAnnouncementsPage({super.key, required this.service});

  @override
  State<DepartmentAnnouncementsPage> createState() =>
      _DepartmentAnnouncementsPageState();
}

class _DepartmentAnnouncementsPageState
    extends State<DepartmentAnnouncementsPage> {
  late Future<List<AnnouncementItem>> _future = _loadAnnouncements();

  Future<List<AnnouncementItem>> _loadAnnouncements() {
    return widget.service.getDepartmentAnnouncements().then(
      (items) => items
          .where((item) => item.authorName.trim().isNotEmpty)
          .where((item) => item.authorName.trim() != 'Ẩn danh')
          .toList(),
    );
  }

  void _reload() {
    setState(() => _future = _loadAnnouncements());
  }

  void _open(AnnouncementItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 700 ? 32.0 : 14.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageTitle('THÔNG BÁO PHÒNG BAN'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Làm mới'),
                ),
              ),
              _buildList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<AnnouncementItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  'Không thể tải thông báo: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                TextButton(onPressed: _reload, child: const Text('Thử lại')),
              ],
            ),
          );
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'Chưa có thông báo nào từ phòng ban',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              AnnouncementCard(item: item, onTap: () => _open(item)),
          ],
        );
      },
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String text;

  const _PageTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
