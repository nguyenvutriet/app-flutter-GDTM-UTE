import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/pages/admin/feedback_detail_page.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/widgets/page_title.dart';

/// Danh sách góp ý tiếp nhận dành cho ADMIN (xem tất cả góp ý).
/// Nhúng trong AppShell nên không có AppBar riêng.
/// Bấm vào 1 góp ý -> [AdminFeedbackDetailPage].
class AdminFeedbackListPage extends StatefulWidget {
  const AdminFeedbackListPage({super.key});

  @override
  State<AdminFeedbackListPage> createState() => _AdminFeedbackListPageState();
}

class _AdminFeedbackListPageState extends State<AdminFeedbackListPage> {
  static const Color hcmuteBlue = Color(0xFF005BAA);
  static const Color pageBackground = Color(0xFFF4F7FB);
  static const Color textPrimary = Color(0xFF172B4D);
  static const Color textSecondary = Color(0xFF667085);
  static const Color borderColor = Color(0xFFE3EAF2);

  static const List<String> _statuses = [
    'ALL',
    'PENDING',
    'APPROVED',
    'FORWARDING',
    'RESOLVED',
    'REJECTED',
  ];

  static const int _pageSize = 12;

  final RequestService _service = RequestService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<Request>>? _sub;

  bool _loading = true;
  String? _error;

  List<Request> _all = [];
  List<Request> _filtered = [];
  final Map<String, String> _categoryNamesById = {};
  final Map<String, String> _departmentNamesById = {};

  String _status = 'ALL';
  String _category = 'ALL';
  String _department = 'ALL'; // lưu departmentId

  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    await _sub?.cancel();

    // Admin: xem tất cả góp ý (không lọc theo phòng ban).
    _sub = _service
        .watchStaffFeedbacks(role: 'ROLE_ADMIN', departmentId: null)
        .listen(
      (data) {
        if (!mounted) return;
        _all = data;
        if (!_categoryOptions.contains(_category)) _category = 'ALL';
        _loading = false;
        _error = null;
        _applyFilters();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      },
    );

    try {
      final snap =
          await FirebaseFirestore.instance.collection('categories').get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final id = (d['id'] ?? doc.id).toString().trim();
        final name = (d['subject'] ?? d['name'] ?? d['title'] ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
      }
      if (!mounted) return;
      _categoryNamesById
        ..clear()
        ..addAll(map);
      _applyFilters();
    } catch (e) {
      debugPrint('ADMIN LIST LOAD CATEGORY ERROR: $e');
    }

    // Tên phòng ban (collection `department`)
    try {
      final snap =
          await FirebaseFirestore.instance.collection('department').get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final id = (d['id'] ?? doc.id).toString().trim();
        final name = (d['name'] ?? d['departmentName'] ?? d['title'] ?? id)
            .toString()
            .trim();
        if (id.isNotEmpty) map[id] = name.isEmpty ? id : name;
      }
      if (!mounted) return;
      _departmentNamesById
        ..clear()
        ..addAll(map);
      _applyFilters();
    } catch (e) {
      debugPrint('ADMIN LIST LOAD DEPARTMENT ERROR: $e');
    }
  }

  String _departmentName(String? id) {
    final key = id?.trim() ?? '';
    if (key.isEmpty) return 'Không xác định';
    return _departmentNamesById[key] ?? key;
  }

  /// Danh sách id phòng ban để lọc: các phòng ban trong Firestore
  /// + phòng ban xuất hiện trong góp ý (phòng khi thiếu trong collection).
  List<String> get _departmentOptions {
    final ids = <String>{..._departmentNamesById.keys};
    for (final r in _all) {
      final id = r.departmentId?.trim() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    final list = ids.toList()
      ..sort((a, b) => _departmentName(a)
          .toLowerCase()
          .compareTo(_departmentName(b).toLowerCase()));
    return ['ALL', ...list];
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<String> _requestCategoryIds(Request r) => r.categoryIds
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> _requestCategoryNames(Request r) {
    final names = <String>{};
    for (final id in _requestCategoryIds(r)) {
      final n = _categoryNamesById[id]?.trim() ?? '';
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) {
      for (final c in r.categories) {
        final n = c.subject?.trim() ?? '';
        if (n.isNotEmpty) names.add(n);
      }
    }
    return names.toList();
  }

  List<String> get _categoryOptions {
    final names = <String>{};
    for (final r in _all) {
      names.addAll(_requestCategoryNames(r));
    }
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['ALL', ...list];
  }

  void _applyFilters() {
    final keyword = _searchController.text.trim().toLowerCase();
    var result = List<Request>.from(_all);

    // 1. Tìm theo tiêu đề (+ nội dung, người gửi cho tiện)
    if (keyword.isNotEmpty) {
      result = result.where((r) {
        return (r.subject ?? '').toLowerCase().contains(keyword) ||
            (r.description ?? '').toLowerCase().contains(keyword) ||
            (r.user?.fullName ?? '').toLowerCase().contains(keyword);
      }).toList();
    }

    // 2. Trạng thái
    if (_status != 'ALL') {
      result = result.where((r) => r.currentStatus == _status).toList();
    }

    // 3. Danh mục
    if (_category != 'ALL') {
      result = result
          .where((r) => _requestCategoryNames(r).contains(_category))
          .toList();
    }

    // 4. Phòng ban
    if (_department != 'ALL') {
      result = result
          .where((r) => (r.departmentId?.trim() ?? '') == _department)
          .toList();
    }

    // Mới nhất trước
    result.sort((a, b) {
      final x = a.timeCreate, y = b.timeCreate;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    if (!mounted) return;
    setState(() {
      _filtered = result;
      _visibleCount = _pageSize;
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _status = 'ALL';
      _category = 'ALL';
      _department = 'ALL';
    });
    _applyFilters();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 400 &&
        _visibleCount < _filtered.length) {
      setState(() => _visibleCount =
          (_visibleCount + _pageSize).clamp(0, _filtered.length));
    }
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  String _statusLabel(String? s) {
    switch (s) {
      case 'ALL':
        return 'Tất cả trạng thái';
      case 'PENDING':
        return 'Đang chờ tiếp nhận';
      case 'APPROVED':
        return 'Đang xử lý';
      case 'FORWARDING':
        return 'Đã được chuyển tiếp';
      case 'RESOLVED':
        return 'Đã xử lý';
      case 'REJECTED':
        return 'Từ chối';
      default:
        return s ?? 'Chưa cập nhật';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'RESOLVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'APPROVED':
        return hcmuteBlue;
      case 'FORWARDING':
        return Colors.purple;
      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'PENDING':
        return Icons.schedule_outlined;
      case 'FORWARDING':
        return Icons.forward_outlined;
      case 'APPROVED':
        return Icons.autorenew_rounded;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _date(DateTime? v) {
    if (v == null) return 'Chưa cập nhật';
    final d = v.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openDetail(Request r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminFeedbackDetailPage(request: r)),
    );
  }

  // ============================================================
  // FILTER SHEETS
  // ============================================================

  Future<void> _pickStatus() async {
    final picked = await _showOptionSheet(
      title: 'Lọc theo trạng thái',
      options: _statuses,
      selected: _status,
      labelOf: _statusLabel,
      leadingOf: (s) => s == 'ALL'
          ? const Icon(Icons.all_inclusive, size: 20, color: textSecondary)
          : Icon(_statusIcon(s), size: 20, color: _statusColor(s)),
    );
    if (picked == null) return;
    setState(() => _status = picked);
    _applyFilters();
  }

  Future<void> _pickCategory() async {
    final picked = await _showOptionSheet(
      title: 'Lọc theo danh mục',
      options: _categoryOptions,
      selected: _category,
      labelOf: (c) => c == 'ALL' ? 'Tất cả danh mục' : c,
      leadingOf: (_) =>
          const Icon(Icons.category_outlined, size: 20, color: textSecondary),
    );
    if (picked == null) return;
    setState(() => _category = picked);
    _applyFilters();
  }

  Future<void> _pickDepartment() async {
    final picked = await _showOptionSheet(
      title: 'Lọc theo phòng ban',
      options: _departmentOptions,
      selected: _department,
      labelOf: (id) => id == 'ALL' ? 'Tất cả phòng ban' : _departmentName(id),
      leadingOf: (_) =>
          const Icon(Icons.business_outlined, size: 20, color: textSecondary),
    );
    if (picked == null) return;
    setState(() => _department = picked);
    _applyFilters();
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required String Function(String) labelOf,
    required Widget Function(String) leadingOf,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((o) {
                      final isSel = o == selected;
                      return ListTile(
                        leading: leadingOf(o),
                        title: Text(
                          labelOf(o),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                isSel ? FontWeight.w800 : FontWeight.w500,
                            color: isSel ? hcmuteBlue : textPrimary,
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(Icons.check_rounded, color: hcmuteBlue)
                            : null,
                        onTap: () => Navigator.pop(ctx, o),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // UI PARTS
  // ============================================================

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Tìm theo tiêu đề...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _searchController.clear,
                icon: const Icon(Icons.clear),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: hcmuteBlue),
        ),
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? hcmuteBlue.withOpacity(.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? hcmuteBlue : borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? hcmuteBlue : textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? hcmuteBlue : textPrimary,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: active ? hcmuteBlue : textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final hasFilter = _status != 'ALL' ||
        _category != 'ALL' ||
        _department != 'ALL' ||
        _searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 10),
        Row(
          children: [
            _filterButton(
              icon: Icons.filter_alt_outlined,
              label: _status == 'ALL' ? 'Trạng thái' : _statusLabel(_status),
              active: _status != 'ALL',
              onTap: _pickStatus,
            ),
            const SizedBox(width: 10),
            _filterButton(
              icon: Icons.category_outlined,
              label: _category == 'ALL' ? 'Danh mục' : _category,
              active: _category != 'ALL',
              onTap: _pickCategory,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _filterButton(
              icon: Icons.business_outlined,
              label: _department == 'ALL'
                  ? 'Phòng ban'
                  : _departmentName(_department),
              active: _department != 'ALL',
              onTap: _pickDepartment,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('${_filtered.length} góp ý',
                style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (hasFilter)
              InkWell(
                onTap: _resetFilters,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt_rounded,
                          size: 16, color: hcmuteBlue),
                      SizedBox(width: 4),
                      Text('Đặt lại',
                          style: TextStyle(
                              color: hcmuteBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String? status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        border: Border.all(color: color.withOpacity(.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 13, color: color),
          const SizedBox(width: 4),
          Text(_statusLabel(status),
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildCard(Request r) {
    final categories = _requestCategoryNames(r);
    final title = r.subject?.trim().isNotEmpty == true
        ? r.subject!
        : 'Không có tiêu đề';
    final sender = r.user?.fullName ?? r.userId ?? 'Ẩn danh';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09172B4D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề + mũi tên
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: textSecondary, size: 22),
                ],
              ),
              const SizedBox(height: 8),

              // Trạng thái + danh mục
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusBadge(r.currentStatus),
                  if (categories.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 160,
                      ),
                      child: _miniInfo(
                          Icons.category_outlined, categories.join(', ')),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: borderColor),
              const SizedBox(height: 10),

              // Phòng ban đang xử lý
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _miniInfo(
                    Icons.business_outlined, _departmentName(r.departmentId)),
              ),

              // Người gửi + ngày gửi
              Row(
                children: [
                  Expanded(
                      child: _miniInfo(Icons.person_outline, sender)),
                  const SizedBox(width: 10),
                  _miniInfo(Icons.schedule_outlined, _date(r.timeCreate)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 64, color: Color(0xFF98A2B3)),
          SizedBox(height: 14),
          Text('Không có góp ý nào',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Thử thay đổi từ khóa hoặc bộ lọc.',
              style: TextStyle(color: textSecondary)),
        ],
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
            const Icon(Icons.error_outline,
                color: Color(0xFFDC2626), size: 52),
            const SizedBox(height: 12),
            const Text('Không thể tải danh sách góp ý',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: pageBackground,
        child: const Center(
          child: CircularProgressIndicator(color: hcmuteBlue),
        ),
      );
    }

    if (_error != null) {
      return Container(color: pageBackground, child: _buildError());
    }

    final visible = _visibleCount.clamp(0, _filtered.length);
    final hasMore = visible < _filtered.length;

    return Container(
      color: pageBackground,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const PageTitle('Góp ý tiếp nhận'),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 8),
            if (_filtered.isEmpty)
              _buildEmpty()
            else ...[
              for (var i = 0; i < visible; i++) _buildCard(_filtered[i]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: hasMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: hcmuteBlue),
                        )
                      : const Text('Đã tải hết danh sách góp ý',
                          style: TextStyle(
                              color: textSecondary, fontSize: 12.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}