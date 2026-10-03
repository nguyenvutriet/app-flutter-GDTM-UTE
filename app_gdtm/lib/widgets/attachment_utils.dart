// lib/widgets/attachment_utils.dart
// Nhận diện loại tệp, định dạng dung lượng / ngày giờ, mở liên kết tải về.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_gdtm/models/FileAttachment.dart';

enum AttachmentKind { pdf, word, excel, other }

/// Phần mở rộng (chữ thường, không có dấu chấm) của tệp đính kèm.
String attachmentExt(FileAttachment a) {
  final type = (a.filestype ?? '').toLowerCase().replaceAll('.', '');
  if (type.isNotEmpty && type.length <= 5 && !type.contains('/')) return type;
  if (type.contains('pdf')) return 'pdf';

  String fromName(String s) {
    final clean = s.split('?').first.toLowerCase();
    final dot = clean.lastIndexOf('.');
    return dot < 0 ? '' : clean.substring(dot + 1);
  }

  final byName = fromName(a.filename ?? '');
  if (byName.isNotEmpty) return byName;
  return fromName(a.fileUrl ?? '');
}

AttachmentKind attachmentKind(FileAttachment a) {
  switch (attachmentExt(a)) {
    case 'pdf':
      return AttachmentKind.pdf;
    case 'doc':
    case 'docx':
      return AttachmentKind.word;
    case 'xls':
    case 'xlsx':
      return AttachmentKind.excel;
    default:
      return AttachmentKind.other;
  }
}

bool isPdf(FileAttachment a) => attachmentKind(a) == AttachmentKind.pdf;

IconData kindIcon(AttachmentKind k) {
  switch (k) {
    case AttachmentKind.pdf:
      return Icons.picture_as_pdf;
    case AttachmentKind.word:
      return Icons.description;
    case AttachmentKind.excel:
      return Icons.table_chart;
    case AttachmentKind.other:
      return Icons.insert_drive_file_outlined;
  }
}

Color kindColor(AttachmentKind k) {
  switch (k) {
    case AttachmentKind.pdf:
      return const Color(0xFFD32F2F);
    case AttachmentKind.word:
      return const Color(0xFF1565C0);
    case AttachmentKind.excel:
      return const Color(0xFF2E7D32);
    case AttachmentKind.other:
      return Colors.black54;
  }
}

String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}

String formatDateTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Mở liên kết ở trình duyệt / ứng dụng ngoài (Word, Excel sẽ được tải về).
Future<void> openUrl(BuildContext context, String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không mở được liên kết.')),
    );
  }
}