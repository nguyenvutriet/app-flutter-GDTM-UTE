// lib/widgets/announcement_card.dart
// Thẻ tóm tắt một thông báo (dùng ở trang Thông báo và trang Quản lý thông báo).
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';

class AnnouncementCard extends StatelessWidget {
  final AnnouncementItem item;
  final VoidCallback onTap;

  const AnnouncementCard({super.key, required this.item, required this.onTap});

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black54),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final dept = item.department?.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 1.5,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                _meta(Icons.person_outline, item.authorName),
                if (dept != null && dept.isNotEmpty) _meta(Icons.apartment, dept),
                _meta(Icons.schedule, formatDateTime(item.date)),
              ]),
              const SizedBox(height: 10),
              Text(item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, height: 1.35)),
              if (item.attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  for (final a in item.attachments.take(4))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(kindIcon(attachmentKind(a)),
                          size: 18, color: kindColor(attachmentKind(a))),
                    ),
                  Text('${item.attachments.length} tệp đính kèm',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}