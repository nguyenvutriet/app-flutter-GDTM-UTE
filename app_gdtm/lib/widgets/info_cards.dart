// lib/widgets/info_cards.dart
// Card thông tin: chạm tên người dùng -> (id, họ tên, email...), chạm tên phòng ban -> thông tin phòng ban.
// Dùng được ở mọi nơi có ForumService: post card, bình luận, reactor sheet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/services/forum_service.dart';
import 'forum_utils.dart';

Future<void> showUserCard(
  BuildContext context,
  ForumService service,
  String userId, {
  String fallbackName = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UserCard(service: service, userId: userId, fallbackName: fallbackName),
  );
}

Future<void> showDepartmentCard(
  BuildContext context,
  ForumService service,
  String departmentId, {
  String fallbackName = '',

  /// Khác null thì hiện nút "Xem bài viết của phòng ban này"
  VoidCallback? onViewPosts,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DepartmentCard(
      service: service,
      departmentId: departmentId,
      fallbackName: fallbackName,
      onViewPosts: onViewPosts,
    ),
  );
}

String _roleLabel(String role) {
  final r = role.toUpperCase();
  if (r.contains('ADMIN')) return 'Quản trị viên';
  if (r.contains('TEACHER') || r.contains('LECTURER')) return 'Giảng viên';
  return 'Sinh viên';
}

// ---------------------------------------------------------------- Người dùng

class _UserCard extends StatefulWidget {
  final ForumService service;
  final String userId;
  final String fallbackName;
  const _UserCard({required this.service, required this.userId, required this.fallbackName});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late final Future<UserInfo?> _future = widget.service.getUserInfo(widget.userId);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: FutureBuilder<UserInfo?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final u = snap.data;
            final name = u?.fullName ?? widget.fallbackName;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              InitialAvatar(name: name.isEmpty ? '?' : name, radius: 34),
              const SizedBox(height: 10),
              Text(name.isEmpty ? 'Ẩn danh' : name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (u != null) ...[
                const SizedBox(height: 4),
                Text(_roleLabel(u.role), style: const TextStyle(color: kFbText2)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                _InfoRow(icon: Icons.badge_outlined, label: 'ID', value: u.id),
                _InfoRow(icon: Icons.person_outline, label: 'Họ tên', value: u.fullName),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: u.email),
                if ((u.departmentName ?? '').isNotEmpty)
                  _InfoRow(
                      icon: Icons.apartment_outlined,
                      label: 'Phòng ban',
                      value: u.departmentName!,
                      copyable: false),
              ] else ...[
                const SizedBox(height: 12),
                Text(snap.hasError ? snap.error.toString() : 'Không tìm thấy thông tin người dùng',
                    textAlign: TextAlign.center, style: const TextStyle(color: kFbText2)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Phòng ban

class _DepartmentCard extends StatefulWidget {
  final ForumService service;
  final String departmentId;
  final String fallbackName;
  final VoidCallback? onViewPosts;
  const _DepartmentCard({
    required this.service,
    required this.departmentId,
    required this.fallbackName,
    this.onViewPosts,
  });

  @override
  State<_DepartmentCard> createState() => _DepartmentCardState();
}

class _DepartmentCardState extends State<_DepartmentCard> {
  late final Future<DepartmentInfo?> _future =
      widget.service.getDepartmentInfo(widget.departmentId);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: FutureBuilder<DepartmentInfo?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final d = snap.data;
            final name = (d?.name.isNotEmpty ?? false) ? d!.name : widget.fallbackName;
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFE7F3FF),
                  child: Icon(Icons.apartment, size: 34, color: kFbBlue),
                ),
                const SizedBox(height: 10),
                Text(name.isEmpty ? 'Phòng ban' : name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                if (d != null) ...[
                  _InfoRow(icon: Icons.tag, label: 'Mã phòng ban', value: d.id),
                  for (final e in d.details)
                    _InfoRow(icon: _iconFor(e.key), label: e.key, value: e.value),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        snap.hasError
                            ? snap.error.toString()
                            : 'Không tìm thấy thông tin phòng ban',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kFbText2)),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  if (widget.onViewPosts != null)
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.filter_alt_outlined, size: 18),
                        label: const Text('Xem bài viết'),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onViewPosts!();
                        },
                      ),
                    ),
                  TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'Email':
        return Icons.email_outlined;
      case 'Điện thoại':
        return Icons.phone_outlined;
      case 'Địa chỉ':
        return Icons.place_outlined;
      case 'Trưởng phòng':
        return Icons.person_outline;
      default:
        return Icons.info_outline;
    }
  }
}

// ------------------------------------------------------------------- Dòng info

class _InfoRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = true,
  });

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(widget.icon, size: 20, color: kFbText2),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.label, style: const TextStyle(fontSize: 12, color: kFbText2)),
            const SizedBox(height: 2),
            SelectableText(empty ? 'Chưa có' : widget.value,
                style: TextStyle(fontSize: 15, color: empty ? kFbText2 : Colors.black87)),
          ]),
        ),
        if (widget.copyable && !empty)
          InkWell(
            onTap: _copy,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(_copied ? Icons.check : Icons.copy,
                  size: 18, color: _copied ? Colors.green : kFbText2),
            ),
          ),
      ]),
    );
  }
}