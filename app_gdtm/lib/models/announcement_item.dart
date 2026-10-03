// lib/models/announcement_item.dart
// View-model của một thông báo: thông báo + người đăng + phòng ban + tệp đính kèm.
import 'package:app_gdtm/models/Announcement.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';

class AnnouncementItem {
  final Announcement announcement;
  final String authorName;
  final String authorRole;

  /// Phòng ban của người đăng (null nếu người đăng chưa thuộc phòng ban nào)
  final Department? department;

  const AnnouncementItem({
    required this.announcement,
    required this.authorName,
    this.authorRole = '',
    this.department,
  });

  String get id => announcement.id ?? '';
  String get title => announcement.title ?? '';
  String get content => announcement.content ?? '';
  DateTime? get date => announcement.date;
  List<FileAttachment> get attachments => announcement.attachments;
}