// Trang Thông báo phòng ban:
// - Lazy loading: tải từng trang 15 thông báo, cuộn gần cuối thì tải tiếp.
// - Bộ lọc phòng ban và tìm kiếm phòng ban dùng TOÀN BỘ phòng ban trong CSDL.
// - Lọc khoảng ngày + sắp xếp thực hiện trên Firestore (đúng với phân trang).
// - Tìm kiếm (không dấu), phòng ban, "có tệp" lọc phía client; nếu chưa đủ kết quả
//   thì tự tải thêm trang tiếp theo.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/pages/common/announcement_detail_page.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/utils/text_search.dart';
import 'package:app_gdtm/widgets/announcement_card.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

enum _Range { all, week, month, custom }

enum _SugType { word, department, title }

class _Suggestion {
  final String text;
  final _SugType type;
  const _Suggestion(this.text, this.type);
}

class _Word {
  final String original;
  int count;
  _Word(this.original) : count = 1;
}

class DepartmentAnnouncementsPage extends StatefulWidget {
  final AnnouncementService service;

  const DepartmentAnnouncementsPage({super.key, required this.service});

  @override
  State<DepartmentAnnouncementsPage> createState() =>
      _DepartmentAnnouncementsPageState();
}

class _DepartmentAnnouncementsPageState
    extends State<DepartmentAnnouncementsPage> {
  static const int _pageSize = 15;
  static const int _minClientResults = 8;
  static const int _maxDeptCards = 3;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Dữ liệu thông báo (đã tải)
  final List<AnnouncementItem> _all = [];
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  Object? _error;
  int _gen = 0; // bỏ qua kết quả của lượt tải cũ khi đã reload

  // Toàn bộ phòng ban trong CSDL
  List<Department> _deptList = [];

  // Chỉ mục phục vụ gợi ý + thẻ phòng ban
  List<String> _departments = [];
  final Map<String, Department> _deptObjects = {};
  final Map<String, _Word> _vocab = {}; // key: từ đã bỏ dấu

  // Bộ lọc
  String? _deptFilter;
  _Range _range = _Range.all;
  DateTimeRange? _customRange;
  bool _onlyAttachments = false;
  bool _newestFirst = true;

  bool _suggestOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDepartments();
      _reload();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 300) _loadMore();
  }

  // ------------------------------------------------------------------
  // TẢI DỮ LIỆU
  // ------------------------------------------------------------------

  Future<void> _loadDepartments() async {
    try {
      final list = await widget.service.getAllDepartments();
      if (!mounted) return;
      setState(() {
        _deptList = list;
        _rebuildIndex();
        if (_deptFilter != null && !_deptObjects.containsKey(_deptFilter)) {
          _deptFilter = null;
        }
      });
    } catch (_) {
      // Không tải được danh sách phòng ban: vẫn dùng phòng ban lấy từ thông báo.
    }
  }

  DateTime? get _dateFrom {
    final now = DateTime.now();
    switch (_range) {
      case _Range.all:
        return null;
      case _Range.week:
        return now.subtract(const Duration(days: 7));
      case _Range.month:
        return now.subtract(const Duration(days: 30));
      case _Range.custom:
        final r = _customRange;
        return r == null
            ? null
            : DateTime(r.start.year, r.start.month, r.start.day);
    }
  }

  DateTime? get _dateTo {
    final r = _customRange;
    if (_range != _Range.custom || r == null) return null;
    return DateTime(
      r.end.year,
      r.end.month,
      r.end.day,
    ).add(const Duration(days: 1));
  }

  /// Xóa danh sách và tải lại từ trang đầu (khi đổi khoảng ngày, sắp xếp, làm mới).
  Future<void> _reload() async {
    _gen++;
    setState(() {
      _all.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loadingFirst = true;
      _loadingMore = false;
      _rebuildIndex();
    });
    await _loadMore();
  }

  /// Tải trang kế tiếp.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final gen = _gen;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await widget.service.getAnnouncementsPage(
        limit: _pageSize,
        startAfter: _cursor,
        from: _dateFrom,
        to: _dateTo,
        descending: _newestFirst,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _all.addAll(
          page.items
              .where((i) => i.authorName.trim().isNotEmpty)
              .where((i) => i.authorName.trim() != 'Ẩn danh'),
        );
        _cursor = page.lastDoc ?? _cursor;
        _hasMore = page.hasMore;
        _loadingFirst = false;
        _loadingMore = false;
        _rebuildIndex();
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loadingFirst = false;
        _loadingMore = false;
      });
      return;
    }
    _afterLoad();
  }

  /// Sau mỗi lần tải / đổi bộ lọc: nếu chưa đủ kết quả hoặc chưa đầy màn hình
  /// thì tải tiếp.
  void _afterLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_needMore()) _loadMore();
    });
  }

  bool _needMore() {
    if (!_hasMore || _loadingMore || _error != null) return false;
    if (_clientFilterActive && _results.length < _minClientResults) {
      return true;
    }
    if (_scroll.hasClients && _scroll.position.maxScrollExtent <= 0) {
      return true;
    }
    return false;
  }

  void _rebuildIndex() {
    _deptObjects.clear();
    _vocab.clear();

    void addWords(String text) {
      final parts = text
          .toLowerCase()
          .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
          .where((w) => w.length >= 2);
      for (final w in parts) {
        final key = normalizeVi(w);
        final existing = _vocab[key];
        if (existing == null) {
          _vocab[key] = _Word(w);
        } else {
          existing.count++;
        }
      }
    }

    // Toàn bộ phòng ban trong CSDL
    for (final d in _deptList) {
      final n = d.name?.trim();
      if (n != null && n.isNotEmpty) {
        _deptObjects.putIfAbsent(n, () => d);
        addWords(n);
      }
    }
    // Dự phòng: phòng ban lấy từ thông báo đã tải
    for (final item in _all) {
      final dept = item.department;
      final dn = dept?.name?.trim();
      if (dept != null && dn != null && dn.isNotEmpty) {
        _deptObjects.putIfAbsent(dn, () => dept);
      }
      addWords(item.title);
      addWords(item.authorName);
    }
    _departments = _deptObjects.keys.toList()..sort();
  }

  // ------------------------------------------------------------------
  // LỌC + TÌM KIẾM (phía client, trên dữ liệu đã tải)
  // ------------------------------------------------------------------

  bool get _clientFilterActive =>
      _deptFilter != null ||
      _onlyAttachments ||
      _controller.text.trim().isNotEmpty;

  bool get _hasActiveFilter => _clientFilterActive || _range != _Range.all;

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<AnnouncementItem> get _results {
    final tokens = tokenizeVi(_controller.text);
    return _all.where((item) {
      final dept = item.department;

      if (_deptFilter != null && dept?.name?.trim() != _deptFilter) {
        return false;
      }
      if (_onlyAttachments && item.attachments.isEmpty) return false;

      if (tokens.isEmpty) return true;
      final hay = normalizeVi(
        [
          item.title,
          item.content,
          item.authorName,
          dept?.name ?? '',
          dept?.description ?? '',
          dept?.location ?? '',
        ].join(' '),
      );
      return containsAllTokens(hay, tokens);
    }).toList();
  }

  /// Phòng ban (trong toàn bộ CSDL) đang được chọn ở bộ lọc hoặc có tên khớp từ khóa.
  List<Department> _matchedDepartments() {
    final tokens = tokenizeVi(_controller.text);
    final out = <Department>[];
    for (final e in _deptObjects.entries) {
      final selected = _deptFilter == e.key;
      final matched =
          tokens.isNotEmpty && containsAllTokens(normalizeVi(e.key), tokens);
      if (selected || matched) out.add(e.value);
    }
    return out;
  }

  /// Đổi bộ lọc phía client rồi tải thêm nếu cần.
  void _changed(VoidCallback fn) {
    setState(() {
      fn();
      _suggestOpen = false;
    });
    _afterLoad();
  }

  void _clearFilters() {
    final needReload = _range != _Range.all;
    setState(() {
      _controller.clear();
      _deptFilter = null;
      _range = _Range.all;
      _customRange = null;
      _onlyAttachments = false;
      _suggestOpen = false;
    });
    if (needReload) {
      _reload();
    } else {
      _afterLoad();
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange,
      helpText: 'Chọn khoảng ngày',
      saveText: 'Áp dụng',
      cancelText: 'Hủy',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _range = _Range.custom;
      _suggestOpen = false;
    });
    _reload();
  }

  // ------------------------------------------------------------------
  // GỢI Ý KIỂU GOOGLE
  // ------------------------------------------------------------------

  List<_Suggestion> _buildSuggestions() {
    final raw = _controller.text;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    final q = normalizeVi(trimmed);
    final out = <_Suggestion>[];
    final seen = <String>{};
    void add(_Suggestion s) {
      if (seen.add('${s.type.name}:${normalizeVi(s.text)}')) out.add(s);
    }

    // 1. Hoàn thành từ đang gõ (từ cuối), giữ nguyên phần đã gõ phía trước
    if (!raw.endsWith(' ')) {
      final parts = trimmed.split(RegExp(r'\s+'));
      final last = normalizeVi(parts.last);
      final head = parts.length > 1
          ? '${parts.sublist(0, parts.length - 1).join(' ')} '
          : '';
      final words =
          _vocab.entries
              .where((e) => e.key.startsWith(last) && e.key != last)
              .toList()
            ..sort((a, b) => b.value.count.compareTo(a.value.count));
      for (final e in words.take(4)) {
        add(_Suggestion('$head${e.value.original}', _SugType.word));
      }
    }

    // 2. Phòng ban khớp (toàn bộ phòng ban trong CSDL)
    var deptCount = 0;
    for (final d in _departments) {
      if (deptCount >= 3) break;
      if (normalizeVi(d).contains(q)) {
        add(_Suggestion(d, _SugType.department));
        deptCount++;
      }
    }

    // 3. Tiêu đề thông báo đã tải khớp
    final tokens = tokenizeVi(trimmed);
    var titleCount = 0;
    for (final item in _all) {
      if (titleCount >= 4) break;
      if (containsAllTokens(normalizeVi(item.title), tokens)) {
        add(_Suggestion(item.title, _SugType.title));
        titleCount++;
      }
    }
    return out;
  }

  void _setText(String t) {
    _controller.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _pickSuggestion(_Suggestion s) {
    _changed(() {
      if (s.type == _SugType.department) {
        _deptFilter = s.text;
        _controller.clear();
      } else {
        _setText(s.text);
      }
    });
  }

  // ------------------------------------------------------------------
  // GIAO DIỆN
  // ------------------------------------------------------------------

  void _open(AnnouncementItem item) {
    setState(() => _suggestOpen = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 700 ? 32.0 : 14.0;
        final items = _results;
        final showList = !_loadingFirst && items.isNotEmpty;

        return CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PageTitle('THÔNG BÁO PHÒNG BAN'),
                    const SizedBox(height: 12),
                    _buildSearchBox(),
                    if (_suggestOpen) _buildSuggestionPanel(),
                    const SizedBox(height: 10),
                    _buildFilters(),
                    const SizedBox(height: 8),
                    _buildDepartmentCards(),
                    _buildStatus(items),
                  ],
                ),
              ),
            ),
            if (showList)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => AnnouncementCard(
                      item: items[i],
                      onTap: () => _open(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
              sliver: SliverToBoxAdapter(child: _buildFooter()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onTap: () => setState(() => _suggestOpen = true),
      onChanged: (_) {
        setState(() => _suggestOpen = true);
        _afterLoad();
      },
      onSubmitted: (_) => setState(() => _suggestOpen = false),
      decoration: InputDecoration(
        hintText: 'Tìm thông báo, phòng ban, người đăng...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa',
                icon: const Icon(Icons.close),
                onPressed: () => _changed(() => _controller.clear()),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildSuggestionPanel() {
    final list = _buildSuggestions();
    if (list.isEmpty) return const SizedBox.shrink();
    final q = _controller.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final s in list)
              InkWell(
                onTap: () => _pickSuggestion(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(_sugIcon(s.type), size: 20, color: Colors.black54),
                      const SizedBox(width: 12),
                      Expanded(child: _highlight(s.text, q)),
                      if (s.type == _SugType.department)
                        const Text(
                          'Phòng ban',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        )
                      else
                        // Điền chữ vào ô tìm kiếm nhưng chưa chốt (giống Google)
                        InkWell(
                          onTap: () => setState(() => _setText(s.text)),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.north_west,
                              size: 18,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _sugIcon(_SugType t) {
    switch (t) {
      case _SugType.word:
        return Icons.search;
      case _SugType.department:
        return Icons.apartment;
      case _SugType.title:
        return Icons.article_outlined;
    }
  }

  /// Phần khớp với từ khóa để thường, phần còn lại in đậm (giống Google).
  Widget _highlight(String text, String query) {
    const normal = TextStyle(fontSize: 15, color: Colors.black87);
    final nt = normalizeVi(text);
    final nq = normalizeVi(query);
    final idx = nq.isEmpty ? -1 : nt.indexOf(nq);
    if (idx < 0 || nt.length != text.length) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: normal,
      );
    }
    final bold = normal.copyWith(fontWeight: FontWeight.bold);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: normal,
        children: [
          TextSpan(text: text.substring(0, idx), style: bold),
          TextSpan(text: text.substring(idx, idx + nq.length)),
          TextSpan(text: text.substring(idx + nq.length), style: bold),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final customLabel = (_range == _Range.custom && _customRange != null)
        ? '${_fmtDate(_customRange!.start)} – ${_fmtDate(_customRange!.end)}'
        : 'Chọn ngày';

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Phòng ban (toàn bộ phòng ban trong CSDL)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _deptFilter == null
                  ? Colors.white
                  : AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: _deptFilter == null ? Colors.black26 : AppColors.primary,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _deptFilter,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả phòng ban'),
                  ),
                  for (final d in _departments)
                    DropdownMenuItem<String?>(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => _changed(() => _deptFilter = v),
              ),
            ),
          ),
        ),
        // Thời gian: nhanh
        for (final r in const [_Range.all, _Range.week, _Range.month])
          ChoiceChip(
            label: Text(switch (r) {
              _Range.all => 'Mọi lúc',
              _Range.week => '7 ngày',
              _Range.month => '30 ngày',
              _Range.custom => '',
            }),
            selected: _range == r,
            onSelected: (_) {
              if (_range == r) return;
              setState(() {
                _range = r;
                _suggestOpen = false;
              });
              _reload();
            },
          ),
        // Thời gian: từ ngày ... đến ngày ...
        ChoiceChip(
          avatar: const Icon(Icons.date_range, size: 16),
          label: Text(customLabel),
          selected: _range == _Range.custom,
          onSelected: (_) => _pickRange(),
        ),
        // Có tệp đính kèm
        FilterChip(
          avatar: const Icon(Icons.attach_file, size: 16),
          label: const Text('Có tệp'),
          selected: _onlyAttachments,
          onSelected: (v) => _changed(() => _onlyAttachments = v),
        ),
        // Sắp xếp
        ActionChip(
          avatar: Icon(
            _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
          ),
          label: Text(_newestFirst ? 'Mới nhất' : 'Cũ nhất'),
          onPressed: () {
            setState(() {
              _newestFirst = !_newestFirst;
              _suggestOpen = false;
            });
            _reload();
          },
        ),
        if (_hasActiveFilter)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Xóa bộ lọc'),
          ),
        TextButton.icon(
          onPressed: () {
            _loadDepartments();
            _reload();
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Làm mới'),
        ),
      ],
    );
  }

  /// Thẻ thông tin chi tiết của phòng ban khớp từ khóa hoặc đang được chọn lọc.
  Widget _buildDepartmentCards() {
    final matched = _matchedDepartments();
    if (matched.isEmpty) return const SizedBox.shrink();

    final shown = matched.take(_maxDeptCards).toList();
    final hidden = matched.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in shown)
          _DepartmentInfoCard(
            department: d,
            isFiltered: _deptFilter == d.name?.trim(),
            onFilter: () => _changed(() {
              _deptFilter = d.name?.trim();
              _controller.clear();
            }),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'và $hidden phòng ban khác, hãy gõ cụ thể hơn hoặc chọn ở bộ lọc.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
      ],
    );
  }

  /// Trạng thái phía trên danh sách: đang tải, lỗi, rỗng, số kết quả.
  Widget _buildStatus(List<AnnouncementItem> items) {
    if (_loadingFirst) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'Không thể tải thông báo: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(onPressed: _reload, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (items.isEmpty && !_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Text(
                _hasActiveFilter
                    ? 'Không tìm thấy thông báo phù hợp'
                    : 'Chưa có thông báo nào từ phòng ban',
                style: const TextStyle(color: Colors.black54),
              ),
              if (_hasActiveFilter)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Xóa tìm kiếm và bộ lọc'),
                ),
            ],
          ),
        ),
      );
    }
    if (items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _hasMore
              ? '${items.length} thông báo (cuộn xuống để tải thêm)'
              : '${items.length} thông báo',
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Chân danh sách: đang tải thêm, lỗi tải thêm, nút tải thêm, hết dữ liệu.
  Widget _buildFooter() {
    if (_loadingFirst) return const SizedBox.shrink();

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_error != null && _all.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              'Không thể tải thêm: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            TextButton(onPressed: _loadMore, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_hasMore) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Tải thêm thông báo'),
        ),
      );
    }
    if (_all.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Đã hiển thị tất cả thông báo',
            style: TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ======================================================================
// THẺ THÔNG TIN PHÒNG BAN
// ======================================================================

class _DepartmentInfoCard extends StatelessWidget {
  final Department department;
  final bool isFiltered;
  final VoidCallback onFilter;

  const _DepartmentInfoCard({
    required this.department,
    required this.isFiltered,
    required this.onFilter,
  });

  Widget _row(IconData icon, String? text, {VoidCallback? onTap}) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  color: onTap == null
                      ? Colors.black87
                      : const Color(0xFF1565C0),
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = department;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.name ?? '',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _row(Icons.info_outline, d.description),
          _row(Icons.location_on_outlined, d.location),
          _row(
            Icons.phone_outlined,
            d.phone,
            onTap: (d.phone ?? '').trim().isEmpty
                ? null
                : () => launchUrl(Uri(scheme: 'tel', path: d.phone)),
          ),
          _row(
            Icons.email_outlined,
            d.email,
            onTap: (d.email ?? '').trim().isEmpty
                ? null
                : () => launchUrl(Uri(scheme: 'mailto', path: d.email)),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onFilter,
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Xem thông báo của phòng ban này'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String text;

  const _PageTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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