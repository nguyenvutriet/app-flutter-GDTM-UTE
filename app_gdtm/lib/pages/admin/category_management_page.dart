// lib/pages/admin/category_management_page.dart
// Quản lý danh mục (admin): thống kê, tìm kiếm, thêm, sửa tên, vô hiệu hóa/kích hoạt.
// Responsive: >= 720px hiển thị dạng bảng, nhỏ hơn hiển thị dạng thẻ.
// embedded = true: dùng bên trong AppShell (không có Scaffold/AppBar riêng).
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/widgets/forum_utils.dart'; // kFbBg, kFbBlue, kFbText2
import 'package:app_gdtm/widgets/page_title.dart';

class CategoryManagementPage extends StatefulWidget {
  final CategoryService service;
  final bool embedded;

  const CategoryManagementPage({
    super.key,
    required this.service,
    this.embedded = false,
  });

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  static const double _wideBreakpoint = 720;
  static const _green = Color(0xFF1E8E3E);
  static const _greenBg = Color(0xFFE6F4EA);
  static const _red = Color(0xFFD93025);
  static const _redBg = Color(0xFFFCE8E6);

  final TextEditingController _searchCtl = TextEditingController();

  List<CategoryStat> _all = [];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  bool? _countAsc; // null = không sắp xếp theo số phản hồi

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
      final r = await widget.service.getAllCategoriesWithStats();
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

  List<CategoryStat> get _filtered {
    final k = _keyword.trim().toLowerCase();
    final list = _all
        .where((s) => k.isEmpty || s.category.subject.toLowerCase().contains(k))
        .toList();
    if (_countAsc != null) {
      list.sort((a, b) => _countAsc!
          ? a.requestCount.compareTo(b.requestCount)
          : b.requestCount.compareTo(a.requestCount));
    }
    return list;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _nameExists(String name, {String? exceptId}) => _all.any((s) =>
      s.category.id != exceptId &&
      s.category.subject.trim().toLowerCase() == name.trim().toLowerCase());

  // ---------------- Actions ----------------

  Future<void> _showNameDialog({CategoryStat? editing}) async {
    final ctl = TextEditingController(text: editing?.category.subject ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(editing == null ? 'Thêm danh mục' : 'Sửa tên danh mục'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: ctl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tên danh mục',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Vui lòng nhập tên danh mục';
                  if (_nameExists(t, exceptId: editing?.category.id)) {
                    return 'Tên danh mục đã tồn tại';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kFbBlue),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setD(() => saving = true);
                      try {
                        if (editing == null) {
                          await widget.service.addCategory(ctl.text);
                        } else {
                          await widget.service
                              .updateSubject(editing.category.id!, ctl.text);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _toast(editing == null
                            ? 'Đã thêm danh mục'
                            : 'Đã cập nhật tên danh mục');
                        _load(silent: true);
                      } catch (e) {
                        setD(() => saving = false);
                        _toast('Lỗi: $e');
                      }
                    },
              child: Text(editing == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
  }

  Future<void> _toggleActive(CategoryStat s) async {
    final disable = s.category.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(disable ? 'Vô hiệu hóa danh mục?' : 'Kích hoạt danh mục?'),
        content: Text(disable
            ? '"${s.category.subject}" sẽ không còn hiển thị khi sinh viên gửi phản hồi mới.'
            : '"${s.category.subject}" sẽ hiển thị trở lại cho sinh viên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: disable ? _red : kFbBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(disable ? 'Vô hiệu hóa' : 'Kích hoạt'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.setActive(s.category.id!, !disable);
      _toast(disable ? 'Đã vô hiệu hóa danh mục' : 'Đã kích hoạt danh mục');
      _load(silent: true);
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
          final items = _filtered;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(wide ? 20 : 12),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.embedded) ...[
                        const PageTitle('QUẢN LÝ DANH MỤC'),
                        const SizedBox(height: 16),
                      ],
                      _stats(),
                      const SizedBox(height: 12),
                      _toolbar(wide),
                      const SizedBox(height: 12),
                      _content(items, wide),
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
        title: const Text('Quản lý danh mục',
            style: TextStyle(color: kFbBlue, fontWeight: FontWeight.w800)),
      ),
      body: body,
    );
  }

  Widget _stats() {
    final total = _all.length;
    final active = _all.where((s) => s.category.isActive).length;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _statChip(Icons.list_alt, 'Tổng: $total', Colors.black87, Colors.white),
      _statChip(Icons.check_box, 'Đang hoạt động: $active', _green, _greenBg),
      _statChip(Icons.block, 'Vô hiệu hóa: ${total - active}', _red, _redBg),
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
          Text(text,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _toolbar(bool wide) {
    final search = TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _keyword = v),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm danh mục...',
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );

    final addBtn = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: kFbBlue,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _showNameDialog(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Thêm Danh Mục'),
    );

    if (wide) {
      return Row(children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        addBtn,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      search,
      const SizedBox(height: 8),
      addBtn,
    ]);
  }

  Widget _content(List<CategoryStat> items, bool wide) {
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
            _keyword.isEmpty ? 'Chưa có danh mục nào' : 'Không tìm thấy danh mục phù hợp',
            style: const TextStyle(color: kFbText2),
          ),
        ),
      );
    }
    return wide ? _table(items) : _cards(items);
  }

  // ---- Dạng bảng (màn hình rộng) ----
  Widget _table(List<CategoryStat> items) {
    const headStyle = TextStyle(
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
            const Expanded(flex: 5, child: Text('TÊN DANH MỤC', style: headStyle)),
            SizedBox(
              width: 180,
              child: InkWell(
                onTap: () => setState(() {
                  _countAsc = _countAsc == null ? false : (_countAsc! ? null : true);
                }),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('SỐ LƯỢNG PHẢN HỒI', style: headStyle),
                  const SizedBox(width: 4),
                  Icon(
                    _countAsc == null
                        ? Icons.unfold_more
                        : (_countAsc! ? Icons.arrow_upward : Icons.arrow_downward),
                    size: 14,
                    color: kFbText2,
                  ),
                ]),
              ),
            ),
            const SizedBox(
              width: 180,
              child: Center(child: Text('TRẠNG THÁI', style: headStyle)),
            ),
            const SizedBox(width: 48),
          ]),
        ),
        const Divider(height: 1),
        for (final s in items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Text(s.category.subject,
                    style: TextStyle(
                      fontSize: 14,
                      color: s.category.isActive ? Colors.black87 : kFbText2,
                    )),
              ),
              SizedBox(width: 180, child: Center(child: _countBadge(s.requestCount))),
              SizedBox(width: 180, child: Center(child: _statusBadge(s.category.isActive))),
              SizedBox(width: 48, child: _menu(s)),
            ]),
          ),
          const Divider(height: 1),
        ],
      ]),
    );
  }

  // ---- Dạng thẻ (màn hình hẹp) ----
  Widget _cards(List<CategoryStat> items) => Column(
        children: [
          for (final s in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.category.subject,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      _statusBadge(s.category.isActive),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat_bubble_outline, size: 14, color: kFbText2),
                        const SizedBox(width: 4),
                        _countBadge(s.requestCount),
                      ]),
                    ]),
                  ]),
                ),
                _menu(s),
              ]),
            ),
        ],
      );

  Widget _countBadge(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F3FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$n',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kFbBlue)),
      );

  Widget _statusBadge(bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _greenBg : _redBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 7, color: active ? _green : _red),
          const SizedBox(width: 5),
          Text(active ? 'Đang hoạt động' : 'Vô hiệu hóa',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? _green : _red)),
        ]),
      );

  Widget _menu(CategoryStat s) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: kFbText2),
        tooltip: 'Tùy chọn',
        onSelected: (v) {
          if (v == 'edit') _showNameDialog(editing: s);
          if (v == 'toggle') _toggleActive(s);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Text('Sửa tên'),
            ]),
          ),
          PopupMenuItem(
            value: 'toggle',
            child: Row(children: [
              Icon(s.category.isActive ? Icons.block : Icons.check_circle_outline,
                  size: 18, color: s.category.isActive ? _red : _green),
              const SizedBox(width: 10),
              Text(s.category.isActive ? 'Vô hiệu hóa' : 'Kích hoạt',
                  style: TextStyle(color: s.category.isActive ? _red : _green)),
            ]),
          ),
        ],
      );
}