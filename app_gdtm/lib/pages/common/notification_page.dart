import 'package:flutter/material.dart';

import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/pages/common/announcement_detail_page.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/widgets/announcement_card.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

/// Trang "Thông báo": tiêu đề + tab Thông báo chung / cá nhân.
/// Tab "Thông báo chung" hiển thị thông báo do giảng viên đăng (mọi role xem được).
/// Tab "Thông báo cá nhân" để trống, làm sau.
class NotificationPage extends StatefulWidget {
  final AnnouncementService service;

  const NotificationPage({super.key, required this.service});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _tab = 0;
  late Future<List<AnnouncementItem>> _future = widget.service.getAnnouncements();

  void _reload() {
    setState(() {
      _future = widget.service.getAnnouncements();
    });
  }

  void _open(AnnouncementItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementDetailPage(item: item)),
    );
  }

  /// Nội dung theo tab đang chọn.
  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildGeneral();
      case 1:
        // TODO: nội dung tab "Thông báo cá nhân"
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneral() {
    return FutureBuilder<List<AnnouncementItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Text(snap.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: _reload, child: const Text('Thử lại')),
            ]),
          );
        }

        final items = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Làm mới'),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Chưa có thông báo nào',
                    style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            for (final item in items)
              AnnouncementCard(item: item, onTap: () => _open(item)),
        ]);
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
              _Tabs(
                index: _tab,
                labels: const ['THÔNG BÁO CHUNG', 'THÔNG BÁO CÁ NHÂN'],
                onChanged: (i) => setState(() => _tab = i),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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