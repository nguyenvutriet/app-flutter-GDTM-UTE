// lib/pages/common/announcement_detail_page.dart
// Chi tiết thông báo: nội dung, thông tin phòng ban đăng, tệp đính kèm.
// PDF hiển thị trực tiếp trong trang; Word / Excel hiện nút "Tải về".
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_view.dart';
import 'package:app_gdtm/widgets/pdf_viewer_page.dart';

class AnnouncementDetailPage extends StatelessWidget {
  final AnnouncementItem item;

  const AnnouncementDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Chi tiết thông báo'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _Panel(children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _meta(Icons.person_outline, item.authorName),
                  _meta(Icons.schedule, formatDateTime(item.date)),
                ]),
                const Divider(height: 24),
                SelectableText(item.content,
                    style: const TextStyle(fontSize: 15.5, height: 1.45)),
              ]),
              const SizedBox(height: 12),
              _departmentPanel(context),
              if (item.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Panel(
                  title: 'Tệp đính kèm (${item.attachments.length})',
                  icon: Icons.attach_file,
                  children: [
                    for (final a in item.attachments) _attachment(context, a),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      );

  // ---------------- Thông tin phòng ban ----------------

  Widget _departmentPanel(BuildContext context) {
    final Department? d = item.department;
    if (d == null) {
      return const _Panel(
        title: 'Thông tin phòng ban',
        icon: Icons.apartment,
        children: [
          Text('Người đăng chưa thuộc phòng ban nào.',
              style: TextStyle(color: Colors.black54)),
        ],
      );
    }

    Widget row(IconData icon, String? text, {VoidCallback? onTap}) {
      if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  color: onTap == null ? Colors.black87 : const Color(0xFF1565C0),
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
            ),
          ]),
        ),
      );
    }

    return _Panel(
      title: 'Thông tin phòng ban',
      icon: Icons.apartment,
      children: [
        Text(d.name ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        row(Icons.info_outline, d.description),
        row(Icons.location_on_outlined, d.location),
        row(Icons.phone_outlined, d.phone,
            onTap: () => launchUrl(Uri(scheme: 'tel', path: d.phone))),
        row(Icons.email_outlined, d.email,
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: d.email))),
      ],
    );
  }

  // ---------------- Tệp đính kèm ----------------

  Widget _attachment(BuildContext context, FileAttachment a) {
    final url = a.fileUrl ?? '';
    final name = a.filename ?? 'Tệp đính kèm';

    if (isPdf(a)) {
      return _viewerBlock(
        context,
        a,
        viewer: PdfView(url: url),
        fullScreenPage: PdfViewerPage(url: url, title: name),
      );
    }

    return _fileTile(context, a);
  }

  /// Khối có tiêu đề (tên tệp, toàn màn hình, tải về) + trình xem nhúng bên dưới.
  Widget _viewerBlock(
    BuildContext context,
    FileAttachment a, {
    required Widget viewer,
    required Widget fullScreenPage,
  }) {
    final kind = attachmentKind(a);
    final size = formatFileSize(a.filesize);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(children: [
            Icon(kindIcon(kind), color: kindColor(kind), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.filename ?? 'Tệp đính kèm',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (size.isNotEmpty)
                  Text(size,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
            IconButton(
              tooltip: 'Xem toàn màn hình',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => fullScreenPage),
              ),
            ),
            IconButton(
              tooltip: 'Tải về',
              icon: const Icon(Icons.download),
              onPressed: () => openUrl(context, a.fileUrl),
            ),
          ]),
        ),
        const Divider(height: 1),
        SizedBox(height: 520, child: viewer),
      ]),
    );
  }

  /// Tệp không xem trực tiếp được (hoặc nền tảng không hỗ trợ): dòng có nút "Tải về".
  Widget _fileTile(BuildContext context, FileAttachment a) {
    final kind = attachmentKind(a);
    final size = formatFileSize(a.filesize);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(kindIcon(kind), color: kindColor(kind), size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.filename ?? 'Tệp đính kèm',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (size.isNotEmpty)
              Text(size, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
        TextButton.icon(
          onPressed: () => openUrl(context, a.fileUrl),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Tải về'),
        ),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final List<Widget> children;

  const _Panel({this.title, this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
            ],
            Text(title!,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ]),
          const Divider(height: 24),
        ],
        ...children,
      ]),
    );
  }
}