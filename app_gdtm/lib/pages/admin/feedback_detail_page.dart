import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_gdtm/models/ClarificationConversation.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/RequestStatusHistory.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/conversation_chat_service.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_view.dart';
import 'package:app_gdtm/widgets/pdf_viewer_page.dart';
import 'package:app_gdtm/widgets/post_link.dart';

/// Chi tiết góp ý dành cho ADMIN (chỉ xem / giám sát).
/// Bố cục mobile: Thông tin chính -> Người gửi -> Lịch sử trạng thái
/// -> Lịch sử chuyển tiếp -> File đính kèm -> Trao đổi.
class AdminFeedbackDetailPage extends StatefulWidget {
  final Request request;

  const AdminFeedbackDetailPage({super.key, required this.request});

  @override
  State<AdminFeedbackDetailPage> createState() =>
      _AdminFeedbackDetailPageState();
}

class _AdminFeedbackDetailPageState extends State<AdminFeedbackDetailPage> {
  static const Color hcmuteBlue = Color(0xFF005BAA);
  static const Color pageBackground = Color(0xFFF4F7FB);
  static const Color textPrimary = Color(0xFF172B4D);
  static const Color textSecondary = Color(0xFF667085);
  static const Color borderColor = Color(0xFFE3EAF2);

  final RequestService _service = RequestService();

  bool _loading = true;
  String? _error;

  late final Request _request;
  FeedbackDetails _details = const FeedbackDetails();

  String? _senderName;
  String? _senderEmail;
  String? _senderRole;
  final Map<String, String> _categoryNames = {};
  final Map<String, String> _departmentNames = {};
  List<_ForwardEntry> _forwards = [];

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getFeedbackDetails(_request),
        _loadSender(),
        _loadCategories(),
        _loadDepartments(),
        _loadForwards(),
      ]);

      if (!mounted) return;
      setState(() => _details = results[0] as FeedbackDetails);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSender() async {
    final userId = _request.userId?.trim();
    if (userId == null || userId.isEmpty) return;

    try {
      Map<String, dynamic>? data;

      final direct = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (direct.exists) {
        data = direct.data();
      } else {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: userId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) data = q.docs.first.data();
      }
      if (data == null) return;

      String pick(List<String> keys) {
        for (final k in keys) {
          final v = (data![k] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      _senderName = pick(['fullName', 'fullname', 'name']);
      _senderEmail = pick(['email']);
      _senderRole = pick(['role']);
    } catch (e) {
      debugPrint('ADMIN LOAD SENDER ERROR: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('categories').get();
      _categoryNames.clear();
      for (final doc in snap.docs) {
        final d = doc.data();
        final id = (d['id'] ?? doc.id).toString().trim();
        final name = (d['subject'] ?? d['name'] ?? d['title'] ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty && name.isNotEmpty) _categoryNames[id] = name;
      }
    } catch (e) {
      debugPrint('ADMIN LOAD CATEGORY ERROR: $e');
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('department').get();
      _departmentNames.clear();
      for (final doc in snap.docs) {
        final d = doc.data();
        final id = (d['id'] ?? doc.id).toString().trim();
        final name =
            (d['name'] ?? d['departmentName'] ?? d['title'] ?? id)
                .toString()
                .trim();
        if (id.isNotEmpty) _departmentNames[id] = name.isEmpty ? id : name;
      }
    } catch (e) {
      debugPrint('ADMIN LOAD DEPARTMENT ERROR: $e');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _departmentName(String? id) {
    final key = id?.trim() ?? '';
    if (key.isEmpty) return 'Không xác định';
    return _departmentNames[key] ?? key;
  }

  String _categoryText() {
    final names = <String>[];
    for (final id in _request.categoryIds) {
      final n = _categoryNames[id.trim()];
      if (n != null && n.isNotEmpty && !names.contains(n)) names.add(n);
    }
    if (names.isEmpty) {
      for (final c in _request.categories) {
        final n = c.subject?.trim() ?? '';
        if (n.isNotEmpty && !names.contains(n)) names.add(n);
      }
    }
    return names.isEmpty ? 'Chưa phân loại' : names.join(', ');
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'PENDING':
        return 'Đang chờ tiếp nhận';
      case 'APPROVED':
        return 'Đang xử lý';
      case 'RESOLVED':
        return 'Đã xử lý';
      case 'REJECTED':
        return 'Từ chối';
      case 'FORWARDING':
        return 'Đã được chuyển tiếp';
      default:
        return s ?? 'Chưa cập nhật';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return hcmuteBlue;
      case 'RESOLVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'FORWARDING':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'PENDING':
        return Icons.schedule_outlined;
      case 'APPROVED':
        return Icons.autorenew_rounded;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'FORWARDING':
        return Icons.forward_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Chưa cập nhật';
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Không rõ dung lượng';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================================================
  // OPEN ATTACHMENT (PDF / ảnh xem trong app, file khác mở ngoài)
  // ============================================================

  Future<void> _openAttachment(FileAttachment a) async {
    final url = a.fileUrl?.trim();

    if (url == null || url.isEmpty) {
      _toast('Không tìm thấy đường dẫn tệp.');
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _toast('Đường dẫn file không hợp lệ.');
      return;
    }

    final fileName = (a.filename ?? '').toLowerCase();

    // Lấy extension từ tên file, nếu không có thì lấy từ URL
    final extension = fileName.contains('.')
        ? fileName.split('.').last
        : uri.path.toLowerCase().split('.').last;

    final isPdfFile = extension == 'pdf';
    final isImage =
        {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(extension);

    // PDF / ẢNH -> xem ngay trong app
    if (isPdfFile || isImage) {
      final Widget preview = isPdfFile
          ? PdfView(url: url)
          : InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('Không thể tải ảnh.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            );

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.96,
              height: MediaQuery.of(context).size.height * 0.92,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPdfFile
                              ? Icons.picture_as_pdf
                              : Icons.image_outlined,
                          color: hcmuteBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.filename ?? 'Tệp đính kèm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: isImage ? Colors.black : Colors.white,
                      child: preview,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      return;
    }

    // Word / Excel / file khác -> mở ứng dụng bên ngoài
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Không thể mở file.');
    } catch (e) {
      _toast('Không thể mở file: $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text('Chi tiết góp ý'),
        centerTitle: true,
        backgroundColor: hcmuteBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: hcmuteBlue))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMainCard(),
                      const SizedBox(height: 14),
                      _buildSenderCard(),
                      const SizedBox(height: 14),
                      _buildStatusTimeline(),
                      const SizedBox(height: 14),
                      // Chỉ hiện khi góp ý đã từng được chuyển tiếp
                      if (_hasForwards) ...[
                        _buildForwardHistory(),
                        const SizedBox(height: 14),
                      ],
                      _buildAttachments(),
                      const SizedBox(height: 14),
                      // Góp ý công khai -> đã lên diễn đàn, không có trao đổi riêng.
                      // Góp ý riêng tư -> hiện các cuộc trao đổi với sinh viên.
                      if (_isPublic)
                        _buildForumLink()
                      else
                        _buildConversations(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Không thể tải chi tiết góp ý',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SHARED UI
  // ============================================================

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09172B4D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: hcmuteBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _statusBadge(String? status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border.all(color: color.withOpacity(.22)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _field(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: .3,
                        color: textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14.5,
                        color: textPrimary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyText(String text) =>
      Text(text, style: const TextStyle(color: textSecondary, fontSize: 13));

  // ============================================================
  // 1. MAIN INFO
  // ============================================================

  Widget _buildMainCard() {
    final r = _request;
    final hasLocation = (r.location ?? '').trim().isNotEmpty;

    return _card(
      title: r.subject?.trim().isNotEmpty == true
          ? r.subject!
          : 'Không có tiêu đề',
      icon: Icons.feedback_outlined,
      trailing: _statusBadge(r.currentStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(Icons.business_outlined, 'Phòng ban xử lý',
              _departmentName(r.departmentId)),
          _field(Icons.schedule_outlined, 'Ngày gửi', _date(r.timeCreate)),
          _field(Icons.category_outlined, 'Danh mục', _categoryText()),
          if (hasLocation)
            _field(Icons.location_on_outlined, 'Địa điểm', r.location!),
          _field(Icons.tag, 'Mã góp ý', r.id ?? 'Không có'),
          const Text('NỘI DUNG GÓP Ý',
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: .3,
                  color: textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              r.description?.trim().isNotEmpty == true
                  ? r.description!
                  : 'Không có nội dung mô tả.',
              style: const TextStyle(
                  color: textPrimary, height: 1.45, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 4. SENDER
  // ============================================================

  Widget _buildSenderCard() {
    final name = (_senderName?.isNotEmpty == true)
        ? _senderName!
        : (_request.user?.fullName ?? _request.userId ?? 'Không có');
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return _card(
      title: 'Thông tin người gửi',
      icon: Icons.badge_outlined,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: hcmuteBlue.withOpacity(.1),
            child: Text(initial,
                style: const TextStyle(
                    color: hcmuteBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary)),
                const SizedBox(height: 3),
                if (_senderEmail?.isNotEmpty == true)
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 14, color: textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(_senderEmail!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: textSecondary, fontSize: 12.5)),
                      ),
                    ],
                  ),
                if (_request.userId?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          _senderRole?.isNotEmpty == true
                              ? '${_request.userId} • $_senderRole'
                              : _request.userId!,
                          style: const TextStyle(
                              color: textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. STATUS TIMELINE
  // ============================================================

  List<RequestStatusHistory> get _sortedHistories {
    final list = List<RequestStatusHistory>.from(_details.histories);
    list.sort((a, b) {
      final x = a.createAt, y = b.createAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return list;
  }

  Widget _buildStatusTimeline() {
    final histories = _sortedHistories;

    return _card(
      title: 'Lịch sử trạng thái',
      icon: Icons.history,
      child: histories.isEmpty
          ? _emptyText('Chưa có lịch sử xử lý.')
          : Column(
              children: [
                for (var i = 0; i < histories.length; i++)
                  _timelineItem(histories[i], isLast: i == histories.length - 1),
              ],
            ),
    );
  }

  Widget _timelineItem(RequestStatusHistory h, {required bool isLast}) {
    final color = _statusColor(h.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(h.status), size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: color.withOpacity(.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusLabel(h.status),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(_date(h.createAt),
                      style: const TextStyle(
                          color: textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 3. FORWARD HISTORY
  // Dữ liệu lấy từ collection `notification` (type REQUEST_FORWARDED):
  // RequestService.forwardRequest lưu ở đó fromDepartmentId, departmentId
  // (nơi nhận), note và createAt.
  // ============================================================

  bool get _hasForwards => _forwards.isNotEmpty;

  Future<void> _loadForwards() async {
    try {
      final id = _request.id;
      if (id == null || id.isEmpty) return;

      final snap = await FirebaseFirestore.instance
          .collection('notification')
          .where('requestId', isEqualTo: id)
          .where('notificationType', isEqualTo: 'REQUEST_FORWARDED')
          .get();

      final list = <_ForwardEntry>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final ts = d['createAt'];
        list.add(_ForwardEntry(
          fromId: (d['fromDepartmentId'] ?? '').toString().trim(),
          toId: (d['departmentId'] ?? '').toString().trim(),
          note: (d['note'] ?? '').toString().trim(),
          time: ts is Timestamp ? ts.toDate() : null,
        ));
      }
      list.sort((a, b) {
        final x = a.time, y = b.time;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
      _forwards = list;
    } catch (e) {
      debugPrint('ADMIN LOAD FORWARDS ERROR: $e');
      _forwards = [];
    }
  }

  Widget _buildForwardHistory() {
    return _card(
      title: 'Lịch sử chuyển tiếp',
      icon: Icons.share_outlined,
      child: Column(
        children: [
          for (final f in _forwards)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _departmentName(f.fromId),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              fontSize: 13.5),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 18, color: Colors.purple),
                      ),
                      Expanded(
                        child: Text(
                          _departmentName(f.toId),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.purple,
                              fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  if (f.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(f.note,
                        style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 6),
                  Text(_date(f.time),
                      style: const TextStyle(
                          color: textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  Widget _buildAttachments() {
    final files = _details.attachments;
    return _card(
      title: 'File đính kèm',
      icon: Icons.attach_file,
      child: files.isEmpty
          ? _emptyText('Không có file đính kèm.')
          : Column(
              children: files
                  .map(
                    (a) => InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openAttachment(a),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined,
                                color: hcmuteBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.filename ?? 'File',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5)),
                                  Text(_fileSize(a.filesize),
                                      style: const TextStyle(
                                          color: textSecondary,
                                          fontSize: 11.5)),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new,
                                size: 18, color: textSecondary),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  // ============================================================
  // 5a. GÓP Ý CÔNG KHAI -> LINK TỚI BÀI TRÊN DIỄN ĐÀN
  // ============================================================

  bool get _isPublic =>
      _request.postStatus == RequestService.postStatusPublic;

  Widget _buildForumLink() {
    final id = _request.id ?? '';

    return _card(
      title: 'Bài viết trên diễn đàn',
      icon: Icons.public,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Góp ý này được đăng công khai trên diễn đàn nên không có trao '
            'đổi riêng. Chạm vào thẻ bên dưới để xem bài viết và bình luận.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (id.isEmpty)
            _emptyText('Không tìm thấy mã bài viết.')
          else
            PostLinkCard(postId: id, url: PostLink.build(id)),
        ],
      ),
    );
  }

  // ============================================================
  // 5. CONVERSATIONS / COMMENTS
  // ============================================================

  Widget _buildConversations() {
    final conversations = _details.conversations;

    return _card(
      title: 'Trao đổi',
      icon: Icons.chat_bubble_outline,
      trailing: Text('${conversations.length}',
          style: const TextStyle(
              color: textSecondary, fontWeight: FontWeight.w700)),
      child: conversations.isEmpty
          ? _emptyText('Chưa có cuộc trao đổi nào.')
          : Column(
              children: conversations.map(_conversationTile).toList(),
            ),
    );
  }

  Widget _conversationTile(ClarificationConversation c) {
    final open = c.isOpen == true;
    final count = (c.messages ?? []).length;
    final color = open ? const Color(0xFF16A34A) : Colors.grey;

    // Material + InkWell (không dùng ListTile/ExpansionTile trong
    // Container có màu nên không bị lỗi "ink splashes may be invisible").
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openConversation(c),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hcmuteBlue.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.forum_outlined,
                      color: hcmuteBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.subject ?? 'Cuộc trao đổi',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            open
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(open ? 'Đang mở' : 'Đã đóng',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                          if (count > 0) ...[
                            const Text('  •  ',
                                style: TextStyle(
                                    fontSize: 12, color: textSecondary)),
                            Text('$count tin nhắn',
                                style: const TextStyle(
                                    fontSize: 12, color: textSecondary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(ClarificationConversation c) {
    final student = (_senderName?.isNotEmpty == true)
        ? _senderName!
        : (_request.user?.fullName ?? _request.userId ?? 'Sinh viên');

    return showDialog<void>(
      context: context,
      builder: (_) => _ConversationDialog(
        conversation: c,
        requestId: _request.id ?? '',
        studentId: _request.userId?.trim() ?? '',
        studentName: student,
      ),
    );
  }
}

class _ForwardEntry {
  final String fromId;
  final String toId;
  final String note;
  final DateTime? time;

  const _ForwardEntry({
    required this.fromId,
    required this.toId,
    required this.note,
    required this.time,
  });
}

// ============================================================
// DIALOG TRAO ĐỔI (admin chỉ xem)
// ============================================================

class _ChatMessage {
  final String content;
  final DateTime? time;
  final String senderId;
  final String receiverId;
  final List<FileAttachment> attachments;

  const _ChatMessage({
    required this.content,
    required this.time,
    required this.senderId,
    required this.receiverId,
    this.attachments = const [],
  });
}

class _ConversationDialog extends StatefulWidget {
  final ClarificationConversation conversation;
  final String requestId;
  final String studentId;
  final String studentName;

  const _ConversationDialog({
    required this.conversation,
    required this.requestId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<_ConversationDialog> createState() => _ConversationDialogState();
}

class _ConversationDialogState extends State<_ConversationDialog> {
  static const Color hcmuteBlue = Color(0xFF005BAA);
  static const Color textPrimary = Color(0xFF172B4D);
  static const Color textSecondary = Color(0xFF667085);
  static const Color borderColor = Color(0xFFE3EAF2);

  bool _loading = true;
  List<_ChatMessage> _messages = [];
  final Map<String, String> _names = {};
  String? _staffId; // người phản hồi (khác sinh viên)
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final convId = widget.conversation.id;
      if (convId != null && convId.isNotEmpty) {
        List<_ChatMessage> list = [];

        // Cách 1: dùng service giống staff (có kèm file đính kèm)
        try {
          final service = ConversationChatService();
          final convs =
              await service.watchConversations(widget.requestId).first;

          ConversationInfo? info;
          for (final c in convs) {
            if (c.docId == convId) {
              info = c;
              break;
            }
          }

          if (info != null) {
            final msgs = await service.watchMessages(info).first;
            list = msgs
                .map((m) => _ChatMessage(
                      content: m.content,
                      time: m.createAt,
                      senderId: m.senderId,
                      receiverId: '',
                      attachments: m.attachments,
                    ))
                .toList();
          }
        } catch (e) {
          debugPrint('ADMIN LOAD VIA SERVICE ERROR: $e');
        }

        // Cách 2 (dự phòng): đọc thẳng collection message, không có ảnh
        if (list.isEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('message')
              .where('clarificationConversationId', isEqualTo: convId)
              .get();

          for (final doc in snap.docs) {
            final d = doc.data();
            final ts = d['createAt'];
            list.add(_ChatMessage(
              content: (d['content'] ?? '').toString(),
              time: ts is Timestamp ? ts.toDate() : null,
              senderId: (d['senderId'] ?? '').toString().trim(),
              receiverId: (d['receiverId'] ?? '').toString().trim(),
            ));
          }
        }

        list.sort((a, b) {
          final x = a.time, y = b.time;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return x.compareTo(y);
        });
        _messages = list;

        for (final m in list) {
          if (m.senderId.isNotEmpty && m.senderId != widget.studentId) {
            _staffId = m.senderId;
            break;
          }
        }
        // Nếu chỉ có tin của sinh viên thì người nhận chính là cán bộ.
        if (_staffId == null) {
          for (final m in list) {
            if (m.senderId == widget.studentId &&
                m.receiverId.isNotEmpty &&
                m.receiverId != widget.studentId) {
              _staffId = m.receiverId;
              break;
            }
          }
        }
        if (_staffId != null) await _resolveName(_staffId!);
      }
    } catch (e) {
      debugPrint('ADMIN LOAD CONVERSATION ERROR: $e');
    }

    // Dự phòng cuối: dùng tin nhắn có sẵn trong model.
    if (_messages.isEmpty) {
      _messages = (widget.conversation.messages ?? [])
          .map((m) => _ChatMessage(
                content: m.content ?? '',
                time: m.createAt,
                senderId: m.senderId ?? '',
                receiverId: m.receiverId ?? '',
              ))
          .toList();
    }

    if (mounted) {
      setState(() => _loading = false);
      // Mở khung là thấy tin nhắn mới nhất ở cuối.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _resolveName(String userId) async {
    try {
      Map<String, dynamic>? data;
      final direct = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (direct.exists) {
        data = direct.data();
      } else {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: userId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) data = q.docs.first.data();
      }
      final name = (data?['fullName'] ?? data?['fullname'] ?? data?['name'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) _names[userId] = name;
    } catch (_) {}
  }

  String get _staffName =>
      (_staffId != null ? _names[_staffId] : null) ?? 'Cán bộ phụ trách';

  bool _isStudent(_ChatMessage m) =>
      m.senderId.isNotEmpty && m.senderId == widget.studentId;

  String _time(DateTime? v) {
    if (v == null) return '';
    final d = v.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  Widget _participant({
    required IconData icon,
    required String name,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: textPrimary,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILE ĐÍNH KÈM TRONG TIN NHẮN
  // ------------------------------------------------------------

  Widget _attachment(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    final isImage = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}
        .contains(attachmentExt(file));

    if (isImage && url.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tải được hình ảnh.'),
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 220,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fileLink(file),
            ),
          ),
        ),
      );
    }
    return _fileLink(file);
  }

  Widget _fileLink(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () {
              if (isPdf(file)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                      url: url,
                      title: file.filename ?? 'Tài liệu PDF',
                    ),
                  ),
                );
              } else {
                openUrl(context, url);
              }
            },
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kindIcon(attachmentKind(file)),
                size: 19, color: kindColor(attachmentKind(file))),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                file.filename ?? 'Tệp đính kèm',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: hcmuteBlue,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    final student = _isStudent(m);
    final color = student ? const Color(0xFFD97706) : hcmuteBlue;
    final name = student ? widget.studentName : _staffName;

    return Align(
      alignment: student ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
        decoration: BoxDecoration(
          color: color.withOpacity(student ? .08 : .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.senderId.isEmpty ? 'Tin nhắn' : name,
              style: TextStyle(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (m.content.trim().isNotEmpty)
              Text(m.content,
                  style: const TextStyle(
                      fontSize: 14, color: textPrimary, height: 1.3)),
            ...m.attachments.map(_attachment),
            const SizedBox(height: 5),
            Text(_time(m.time),
                style:
                    const TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.conversation.isOpen == true;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.forum_outlined, color: hcmuteBlue, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Trao đổi với sinh viên',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(widget.conversation.subject ?? 'Cuộc trao đổi',
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: textPrimary)),
              const SizedBox(height: 2),
              Text.rich(TextSpan(
                style:
                    const TextStyle(fontSize: 12.5, color: textSecondary),
                children: [
                  const TextSpan(text: 'Trạng thái: '),
                  TextSpan(
                    text: open ? 'Đang mở' : 'Đã đóng',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )),
              const SizedBox(height: 12),

              // Hai bên tham gia hội thoại
              Row(
                children: [
                  _participant(
                    icon: Icons.school_outlined,
                    name: widget.studentName,
                    color: const Color(0xFFD97706),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.sync_alt_rounded,
                        size: 16, color: textSecondary),
                  ),
                  _participant(
                    icon: Icons.support_agent_outlined,
                    name: _loading ? '...' : _staffName,
                    color: hcmuteBlue,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: hcmuteBlue),
                        )
                      : _messages.isEmpty
                          ? const Center(
                              child: Text('Chưa có tin nhắn.',
                                  style: TextStyle(color: textSecondary)),
                            )
                          : ListView(
                              controller: _scroll,
                              children: _messages.map(_bubble).toList(),
                            ),
                ),
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        open
                            ? Icons.visibility_outlined
                            : Icons.lock_outline_rounded,
                        size: 18,
                        color: textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        open
                            ? 'Cuộc trao đổi đang mở. Bạn đang xem với tư cách quản trị viên, không thể nhắn tin.'
                            : 'Cuộc trao đổi đã được đóng. Bạn chỉ có thể xem lại nội dung.',
                        style: const TextStyle(
                            fontSize: 12.5, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}