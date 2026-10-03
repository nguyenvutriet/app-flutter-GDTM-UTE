// lib/pages/admin/violation_comments_page.dart
// Quản lý bình luận vi phạm (admin): thống kê, tìm kiếm, lọc ngày, lọc trạng thái,
// xem nguồn (bài viết), duyệt "Không vi phạm" / "Vi phạm — ẩn bình luận".
// Responsive: >= 900px dạng bảng, nhỏ hơn dạng thẻ. embedded = true: dùng trong AppShell.
import 'package:flutter/material.dart';

import 'package:app_gdtm/pages/student/post_detail_page.dart';
import 'package:app_gdtm/services/comment_report_service.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart'; // kFbBg, kFbBlue, kFbText2
import 'package:app_gdtm/widgets/page_title.dart';

class ViolationCommentsPage extends StatefulWidget {
  final CommentReportService service;

  /// Dùng để mở bài viết gốc khi bấm "Xem"
  final ForumService forum;
  final bool embedded;

  const ViolationCommentsPage({
    super.key,
    required this.service,
    required this.forum,
    this.embedded = false,
  });

  @override
  State<ViolationCommentsPage> createState() => _ViolationCommentsPageState();
}

class _ViolationCommentsPageState extends State<ViolationCommentsPage> {
  static const double _wideBreakpoint = 900;
  static const _green = Color(0xFF1E8E3E);
  static const _greenBg = Color(0xFFE6F4EA);
  static const _red = Color(0xFFD93025);
  static const _redBg = Color(0xFFFCE8E6);
  static const _orange = Color(0xFFE37400);
  static const _orangeBg = Color(0xFFFEF3E0);

  static const Map<String, String> _statusFilters = {
    'all': 'Tất cả',
    ReportStatus.pending: 'Đang chờ',
    ReportStatus.notViolation: 'Không vi phạm',
    ReportStatus.violation: 'Vi phạm',
  };

  final TextEditingController _searchCtl = TextEditingController();

  List<ReportItem> _all = [];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  String _status = 'all';
  DateTimeRange? _range;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await widget.service.getReports();
      if (!mounted) return;
      setState(() {
        _all = r;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ReportItem> get _filtered {
    final k = _keyword.trim().toLowerCase();
    final list = _all.where((r) {
      if (_status != 'all' && r.status != _status) return false;
      if (_range != null) {
        final d = r.createdAt;
        if (d == null) return false;
        final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day)
            .add(const Duration(days: 1));
        if (d.isBefore(start) || !d.isBefore(end)) return false;
      }
      if (k.isEmpty) return true;
      return r.commentContent.toLowerCase().contains(k) ||
          r.reason.toLowerCase().contains(k) ||
          r.reporterName.toLowerCase().contains(k);
    }).toList();
    list.sort((a, b) {
      final x = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final y = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _newestFirst ? y.compareTo(x) : x.compareTo(y);
    });
    return list;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _p2(int n) => n.toString().padLeft(2, '0');
  String _date(DateTime d) => '${_p2(d.day)}/${_p2(d.month)}/${d.year}';
  String _dateTime(DateTime? d) =>
      d == null ? '' : '${_date(d)} ${_p2(d.hour)}:${_p2(d.minute)}';

  // ---------------- Actions ----------------

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range,
      helpText: 'Chọn khoảng ngày báo cáo',
      saveText: 'Áp dụng',
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _resolve(ReportItem r, bool violation) async {
    if (violation) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận vi phạm?'),
          content: const Text(
              'Bình luận sẽ bị ẩn với mọi người dùng (admin vẫn thấy ở dạng mờ). '
              'Các báo cáo đang chờ của bình luận này cũng được chốt là vi phạm.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ẩn bình luận'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await widget.service.resolve(r, violation: violation);
      _toast(violation ? 'Đã ẩn bình luận vi phạm' : 'Đã đánh dấu không vi phạm');
      _load(silent: true);
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  /// Ẩn / hiện lại bình luận của một báo cáo đã xử lý.
  Future<void> _toggleHidden(ReportItem r) async {
    final hide = !r.commentHidden;
    if (hide) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ẩn bình luận?'),
          content: const Text(
              'Bình luận sẽ bị ẩn với mọi người dùng (admin vẫn thấy ở dạng mờ).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ẩn bình luận'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await widget.forum.setCommentHidden(r.commentId, hidden: hide);
      _toast(hide ? 'Đã ẩn bình luận' : 'Đã hiện lại bình luận');
      _load(silent: true);
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  Future<void> _openSource(ReportItem r) async {
    final id = r.requestId;
    if (id == null || id.isEmpty) {
      _toast('Không tìm thấy bài viết của bình luận này');
      return;
    }
    try {
      final post = await widget.forum.getPostDetail(id);
      if (!mounted) return;
      if (post == null) {
        _toast('Bài viết không còn tồn tại');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(
            initialPost: post,
            service: widget.forum,
            focusCommentId: r.commentId, // cuộn tới đúng bình luận bị báo cáo
            canReport: false, // admin không báo cáo
          ),
        ),
      );
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: kFbBg,
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= _wideBreakpoint;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(wide ? 20 : 12),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.embedded) ...[
                        const PageTitle('QUẢN LÝ BÌNH LUẬN VI PHẠM'),
                        const SizedBox(height: 16),
                      ],
                      _stats(),
                      const SizedBox(height: 12),
                      _toolbar(wide),
                      const SizedBox(height: 12),
                      _content(_filtered, wide),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: kFbBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('Quản lý bình luận vi phạm',
            style: TextStyle(color: kFbBlue, fontWeight: FontWeight.w800)),
      ),
      body: body,
    );
  }

  Widget _stats() {
    int n(String s) => _all.where((r) => r.status == s).length;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _statChip(Icons.list_alt, 'Tổng: ${_all.length}', Colors.black87, Colors.white),
      _statChip(Icons.hourglass_empty, 'Đang chờ: ${n(ReportStatus.pending)}', _orange, _orangeBg),
      _statChip(Icons.check_box, 'Không vi phạm: ${n(ReportStatus.notViolation)}', _green, _greenBg),
      _statChip(Icons.block, 'Vi phạm: ${n(ReportStatus.violation)}', _red, _redBg),
    ]);
  }

  Widget _statChip(IconData icon, String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _toolbar(bool wide) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    final search = TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _keyword = v),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm nội dung bình luận, lý do...',
        prefixIcon: const Icon(Icons.search, color: kFbText2, size: 20),
        suffixIcon: _keyword.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: kFbText2, size: 18),
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _keyword = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border,
        enabledBorder: border,
      ),
    );

    final dateBtn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _pickRange,
      icon: const Icon(Icons.calendar_today, size: 16, color: kFbText2),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          _range == null
              ? 'Từ ngày – Đến ngày'
              : '${_date(_range!.start)} – ${_date(_range!.end)}',
          style: const TextStyle(fontSize: 13),
        ),
        if (_range != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _range = null),
            child: const Icon(Icons.close, size: 16, color: kFbText2),
          ),
        ],
      ]),
    );

    final statusDd = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          icon: const Icon(Icons.arrow_drop_down, color: kFbText2),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: _statusFilters.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? 'all'),
        ),
      ),
    );

    if (wide) {
      return Row(children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        dateBtn,
        const SizedBox(width: 12),
        statusDd,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      search,
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: dateBtn),
        const SizedBox(width: 8),
        statusDd,
      ]),
    ]);
  }

  Widget _content(List<ReportItem> items, bool wide) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ]),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _all.isEmpty ? 'Chưa có báo cáo nào' : 'Không có báo cáo phù hợp',
            style: const TextStyle(color: kFbText2),
          ),
        ),
      );
    }
    return wide ? _table(items) : _cards(items);
  }

  // ---- Dạng bảng ----
  Widget _table(List<ReportItem> items) {
    const head = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: kFbText2, letterSpacing: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const Expanded(flex: 5, child: Text('BÌNH LUẬN', style: head)),
            const Expanded(flex: 4, child: Text('LÝ DO BÁO CÁO', style: head)),
            const Expanded(flex: 2, child: Text('NGƯỜI BÁO CÁO', style: head)),
            SizedBox(
              width: 130,
              child: InkWell(
                onTap: () => setState(() => _newestFirst = !_newestFirst),
                child: Row(children: [
                  const Text('THỜI GIAN', style: head),
                  const SizedBox(width: 4),
                  Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14, color: kFbText2),
                ]),
              ),
            ),
            const SizedBox(width: 70, child: Center(child: Text('NGUỒN', style: head))),
            const SizedBox(width: 130, child: Center(child: Text('TRẠNG THÁI', style: head))),
            const SizedBox(width: 40),
          ]),
        ),
        const Divider(height: 1),
        for (final r in items) ...[
          _row(r),
          const Divider(height: 1),
        ],
      ]),
    );
  }

  Widget _row(ReportItem r) {
    final dim = r.commentHidden;
    final color = dim ? kFbText2 : Colors.black87;
    Widget txt(String s, {bool bold = false, bool strike = false}) => Text(
          s,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(flex: 5, child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: txt(r.commentContent, strike: dim),
        )),
        Expanded(flex: 4, child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: txt(r.reason, bold: true),
        )),
        Expanded(flex: 2, child: txt(r.reporterName)),
        SizedBox(width: 130, child: txt(_dateTime(r.createdAt))),
        SizedBox(width: 70, child: Center(child: _viewBtn(r))),
        SizedBox(width: 130, child: Center(child: _statusBadge(r.status))),
        SizedBox(width: 40, child: _menu(r)),
      ]),
    );
  }

  // ---- Dạng thẻ ----
  Widget _cards(List<ReportItem> items) => Column(
        children: [
          for (final r in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.commentContent,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: r.commentHidden ? kFbText2 : Colors.black87,
                          decoration:
                              r.commentHidden ? TextDecoration.lineThrough : null,
                        )),
                    const SizedBox(height: 6),
                    Text('Lý do: ${r.reason}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${r.reporterName} • ${_dateTime(r.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: kFbText2)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      _statusBadge(r.status),
                      _viewBtn(r),
                    ]),
                  ]),
                ),
                _menu(r),
              ]),
            ),
        ],
      );

  Widget _viewBtn(ReportItem r) => InkWell(
        onTap: () => _openSource(r),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('Xem',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kFbBlue)),
        ),
      );

  Widget _statusBadge(String status) {
    late final String label;
    late final Color fg;
    late final Color bg;
    late final IconData icon;
    switch (status) {
      case ReportStatus.notViolation:
        label = 'Không vi phạm';
        fg = _green;
        bg = _greenBg;
        icon = Icons.circle;
        break;
      case ReportStatus.violation:
        label = 'Vi phạm';
        fg = _red;
        bg = _redBg;
        icon = Icons.circle;
        break;
      default:
        label = 'Đang chờ';
        fg = _orange;
        bg = _orangeBg;
        icon = Icons.circle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 7, color: fg),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }

  /// Báo cáo đang chờ: duyệt (Không vi phạm / Vi phạm — ẩn).
  /// Báo cáo đã xử lý: chốt rồi, chỉ còn ẩn / hiện lại bình luận.
  Widget _menu(ReportItem r) {
    final pending = r.status == ReportStatus.pending;
    // Đã xử lý mà bình luận không còn (bị xóa) thì không còn thao tác nào
    if (!pending && (!r.commentExists || !r.commentActive)) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: kFbText2),
      tooltip: pending ? 'Duyệt báo cáo' : 'Quản lý bình luận',
      onSelected: (v) {
        if (v == 'ok') _resolve(r, false);
        if (v == 'bad') _resolve(r, true);
        if (v == 'toggle') _toggleHidden(r);
      },
      itemBuilder: (_) => pending
          ? const [
              PopupMenuItem(
                value: 'ok',
                child: Row(children: [
                  Icon(Icons.check_box, size: 18, color: _green),
                  SizedBox(width: 10),
                  Text('Không vi phạm', style: TextStyle(color: _green)),
                ]),
              ),
              PopupMenuItem(
                value: 'bad',
                child: Row(children: [
                  Icon(Icons.block, size: 18, color: _red),
                  SizedBox(width: 10),
                  Text('Vi phạm — ẩn bình luận', style: TextStyle(color: _red)),
                ]),
              ),
            ]
          : [
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(r.commentHidden ? Icons.visibility : Icons.visibility_off,
                      size: 18, color: r.commentHidden ? _green : _red),
                  const SizedBox(width: 10),
                  Text(r.commentHidden ? 'Hiện lại bình luận' : 'Ẩn bình luận',
                      style: TextStyle(color: r.commentHidden ? _green : _red)),
                ]),
              ),
            ],
    );
  }
}