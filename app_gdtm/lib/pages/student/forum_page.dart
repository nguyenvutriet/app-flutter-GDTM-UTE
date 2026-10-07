// lib/pages/student/forum_page.dart
// Bảng tin diễn đàn kiểu Facebook: tìm kiếm từng chữ, lọc ngày / phòng ban,
// sắp xếp, cuộn vô hạn (kể cả khi đang tìm/lọc), kéo để làm mới.
// embedded = true: dùng bên trong AppShell (không có Scaffold/AppBar riêng).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';
import 'package:app_gdtm/widgets/info_cards.dart';
import 'package:app_gdtm/widgets/post_card.dart';
import 'package:app_gdtm/widgets/reactors_sheet.dart';
import 'post_detail_page.dart';
import 'package:app_gdtm/widgets/report_comment_dialog.dart';

class ForumPage extends StatefulWidget {
  final ForumService service;

  /// Tên người dùng hiện tại (cho avatar ô soạn bài)
  final String currentUserName;

  /// Mở màn hình gửi góp ý. Null thì ẩn ô "Bạn muốn góp ý điều gì?"
  final VoidCallback? onCompose;

  /// true = nhúng trong AppShell, không vẽ Scaffold/AppBar
  final bool embedded;

  /// false = ẩn nút "Báo cáo" bình luận (dùng cho admin)
  final bool canReport;

  const ForumPage({
    super.key,
    required this.service,
    this.currentUserName = '',
    this.onCompose,
    this.embedded = false,
    this.canReport = true,
  });

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  static const Map<String, String> _sorts = {
    'newest': 'Mới nhất',
    'oldest': 'Cũ nhất',
    'mostReactions': 'Nhiều tương tác',
    'mostComments': 'Nhiều bình luận',
  };

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  // Hộp gợi ý dưới thanh tìm kiếm
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _searchLink = LayerLink();
  Timer? _suggestTimer;
  int _sgGen = 0;
  bool _showSuggest = false;
  List<SearchSuggestion> _suggestions = [];

  List<ForumPostDTO> _posts = [];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _hasMore = true;
  bool _searching = false; // chỉ dùng khi không embedded
  String _sortBy = 'newest';
  String _keyword = '';
  String? _error;
  bool _isAdmin = false;
  final Set<String> _reportedPosts = {};

  // Bộ lọc
  String? _departmentId;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<DepartmentInfo> _departments = [];

  /// Mỗi lần tải mới tăng 1, kết quả của lần tải cũ (đã bị thay thế) sẽ bị bỏ.
  int _gen = 0;

  bool get _hasFilter => _departmentId != null || _fromDate != null;
  bool get _hasQuery => _keyword.isNotEmpty || _hasFilter;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!mounted) return;
      if (_searchFocus.hasFocus) {
        _openSuggest();
      } else {
        // Chờ một chút để chạm vào dòng gợi ý kịp được xử lý trước khi đóng hộp
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocus.hasFocus && _showSuggest) {
            setState(() => _showSuggest = false);
          }
        });
      }
    });
    _loadMeta();
    _loadDepartments();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMoreIfNeeded();
      }
    });
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestTimer?.cancel();
    _searchFocus.dispose();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (_hasMore && !_loading && _error == null) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts = [];
        _last = null;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.service.getPublicPosts(
        startAfter: reset ? null : _last,
        sortBy: _sortBy,
        keyword: _keyword,
        departmentId: _departmentId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _posts = [..._posts, ...page.posts];
        _last = page.lastDoc ?? _last;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e.toString());
    } finally {
      if (mounted && gen == _gen) {
        setState(() => _loading = false);
        _fillIfShort();
      }
    }
  }

  /// Khi lọc/tìm kiếm trả về ít bài, danh sách chưa đủ dài để cuộn
  /// (không có sự kiện cuộn để tải tiếp) -> tự tải thêm.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent - _scroll.position.pixels < 400) {
        _loadMoreIfNeeded();
      }
    });
  }

  Future<void> _loadMeta() async {
    try {
      final admin = await widget.service.isAdmin();
      final ids = (!admin && widget.canReport)
          ? await widget.service.getMyReportedPostIds()
          : <String>{};
      if (!mounted) return;
      setState(() {
        _isAdmin = admin;
        _reportedPosts.addAll(ids);
      });
    } catch (_) {}
  }

  Future<void> _loadDepartments() async {
    try {
      final list = await widget.service.getDepartments();
      if (mounted) setState(() => _departments = list);
    } catch (_) {}
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reportPost(ForumPostDTO p) async {
    final ok = await showReportPostDialog(context, service: widget.service, post: p);
    if (ok && mounted) setState(() => _reportedPosts.add(p.id));
  }

  Future<void> _toggleHidden(ForumPostDTO p) async {
    final hide = !p.isHidden;
    if (hide) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ẩn bài viết?'),
          content: const Text(
              'Bài viết sẽ không còn hiển thị với người dùng khác. '
              'Bạn vẫn thấy ở dạng mờ và có thể hiện lại bất cứ lúc nào.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ẩn')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await widget.service.setPostHidden(p.id, hidden: hide);
      _replace(p.id, (x) => x.copyWith(isHidden: hide));
      _snack(hide ? 'Đã ẩn bài viết' : 'Đã hiện lại bài viết');
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _replace(String id, ForumPostDTO Function(ForumPostDTO) fn) {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0 || !mounted) return;
    setState(() => _posts[i] = fn(_posts[i]));
  }

  Future<void> _react(ForumPostDTO p, String type) async {
    try {
      final r = await widget.service.votePost(p.id, type);
      _replace(
        p.id,
        (x) => x.copyWith(
          reactions: r.counts,
          reactionType: r.currentType,
          clearReaction: r.currentType == null,
        ),
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _openDetail(ForumPostDTO p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          initialPost: p,
          service: widget.service,
          canReport: widget.canReport,
          onPostChanged: (np) => _replace(np.id, (_) => np),
        ),
      ),
    );
  }

  // ---------------- Card thông tin ----------------

  void _showUser(String userId, String name) =>
      showUserCard(context, widget.service, userId, fallbackName: name);

  void _showDepartment(ForumPostDTO p) {
    showDepartmentCard(
      context,
      widget.service,
      p.departmentId,
      fallbackName: p.departmentName,
      onViewPosts: p.departmentId.isEmpty
          ? null
          : () {
              setState(() => _departmentId = p.departmentId);
              _reloadFromTop();
            },
    );
  }

  // ---------------- Tìm kiếm / lọc ----------------

  void _reloadFromTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load(reset: true);
  }

  /// Gõ tới đâu tìm tới đó (chờ 400ms sau lần gõ cuối).
  void _onSearchChanged(String v) {
    setState(() => _showSuggest = true); // cập nhật nút xóa (x) + mở hộp gợi ý
    _scheduleSuggest(v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final kw = v.trim();
      if (kw == _keyword) return;
      _keyword = kw;
      _reloadFromTop();
    });
  }

  void _submitSearch(String v) {
    _debounce?.cancel();
    _keyword = v.trim();
    widget.service.addRecentSearch(_keyword);
    _hideSuggest();
    _reloadFromTop();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtl.clear();
    _keyword = '';
    setState(() => _suggestions = []);
    _reloadFromTop();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _keyword.isNotEmpty) _clearSearch();
  }

  // ---------------- Hộp gợi ý ----------------

  void _openSuggest() {
    if (!mounted) return;
    setState(() => _showSuggest = true);
    _scheduleSuggest(_searchCtl.text, immediate: true);
  }

  void _hideSuggest() {
    _suggestTimer?.cancel();
    _sgGen++;
    _searchFocus.unfocus();
    if (mounted) setState(() => _showSuggest = false);
  }

  /// Gõ xong 200ms mới lấy gợi ý (kết quả cũ đến trễ sẽ bị bỏ).
  void _scheduleSuggest(String text, {bool immediate = false}) {
    _suggestTimer?.cancel();
    final kw = text.trim();
    if (kw.isEmpty) {
      _sgGen++;
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _suggestTimer = Timer(Duration(milliseconds: immediate ? 0 : 200), () async {
      final gen = ++_sgGen;
      try {
        final list = await widget.service.getSuggestions(kw);
        if (!mounted || gen != _sgGen) return;
        setState(() => _suggestions = list);
      } catch (_) {
        if (mounted && gen == _sgGen) setState(() => _suggestions = []);
      }
    });
  }

  /// Chọn một gợi ý / lịch sử: tìm ngay theo cụm đó.
  void _applyKeyword(String kw) {
    _debounce?.cancel();
    _searchCtl.text = kw;
    _searchCtl.selection = TextSelection.collapsed(offset: kw.length);
    _keyword = kw.trim();
    widget.service.addRecentSearch(_keyword);
    _hideSuggest();
    _reloadFromTop();
  }

  /// Chọn gợi ý phòng ban: bỏ từ khóa, lọc theo phòng ban đó.
  void _applyDepartment(SearchSuggestion s) {
    _debounce?.cancel();
    _searchCtl.clear();
    _keyword = '';
    _departmentId = s.departmentId;
    _hideSuggest();
    _reloadFromTop();
  }

  /// Đưa chữ gợi ý lên ô nhập để sửa tiếp (mũi tên ↖), chưa tìm.
  void _fillKeyword(String kw) {
    _searchCtl.text = kw;
    _searchCtl.selection = TextSelection.collapsed(offset: kw.length);
    _onSearchChanged(kw);
  }

  /// Tô đậm các chữ trùng từ khóa (không phân biệt hoa/thường, dấu).
  Widget _highlighted(String text, List<String> tokens) {
    const base = TextStyle(fontSize: 14.5, color: Colors.black87);
    final folded = foldVi(text);
    if (tokens.isEmpty || folded.length != text.length) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final mark = List<bool>.filled(text.length, false);
    for (final t in tokens) {
      var i = folded.indexOf(t);
      while (i >= 0) {
        for (var k = i; k < i + t.length; k++) {
          mark[k] = true;
        }
        i = folded.indexOf(t, i + 1);
      }
    }
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || mark[i] != mark[start]) {
        spans.add(TextSpan(
          text: text.substring(start, i),
          style: mark[start] ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ));
        start = i;
      }
    }
    return Text.rich(TextSpan(style: base, children: spans),
        maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _suggestOverlay() {
    if (!_showSuggest) return const SizedBox.shrink();

    final kw = _searchCtl.text.trim();
    final tokens = searchTokens(kw);
    final history = widget.service.recentSearches;
    final rows = <Widget>[];

    if (kw.isEmpty) {
      // Chưa gõ gì: hiện lịch sử tìm kiếm
      if (history.isEmpty) return const SizedBox.shrink();
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          const Expanded(
            child: Text('Tìm kiếm gần đây',
                style: TextStyle(fontWeight: FontWeight.w700, color: kFbText2)),
          ),
          TextButton(
            onPressed: () {
              widget.service.clearRecentSearches();
              setState(() {});
            },
            child: const Text('Xóa tất cả'),
          ),
        ]),
      ));
      for (final h in List<String>.from(history)) {
        rows.add(ListTile(
          dense: true,
          leading: const Icon(Icons.history, color: kFbText2),
          title: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18, color: kFbText2),
            onPressed: () {
              widget.service.removeRecentSearch(h);
              setState(() {});
            },
          ),
          onTap: () => _applyKeyword(h),
        ));
      }
    } else {
      // Dòng đầu: tìm đúng cụm đang gõ
      rows.add(ListTile(
        dense: true,
        leading: const Icon(Icons.search, color: kFbBlue),
        title: Text.rich(TextSpan(children: [
          const TextSpan(text: 'Tìm "'),
          TextSpan(text: kw, style: const TextStyle(fontWeight: FontWeight.w700)),
          const TextSpan(text: '"'),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _applyKeyword(kw),
      ));
      for (final s in _suggestions) {
        if (s.type == SuggestionType.department) {
          rows.add(ListTile(
            dense: true,
            leading: const Icon(Icons.apartment_outlined, color: kFbText2),
            title: _highlighted(s.text, tokens),
            subtitle: const Text('Lọc theo phòng ban', style: TextStyle(fontSize: 12)),
            onTap: () => _applyDepartment(s),
          ));
        } else {
          rows.add(ListTile(
            dense: true,
            leading: const Icon(Icons.article_outlined, color: kFbText2),
            title: _highlighted(s.text, tokens),
            trailing: IconButton(
              tooltip: 'Điền vào ô tìm kiếm',
              icon: const Icon(Icons.north_west, size: 18, color: kFbText2),
              onPressed: () => _fillKeyword(s.text),
            ),
            onTap: () => _applyKeyword(s.text),
          ));
        }
      }
    }

    final panel = TextFieldTapRegion(
      child: Material(
        color: Colors.white,
        elevation: 6,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: rows,
          ),
        ),
      ),
    );

    // Có AppBar riêng: ô tìm kiếm nằm sát mép trên của body -> đặt ngay mép trên.
    // Nhúng trong AppShell: bám theo thanh tìm kiếm trong danh sách (cuộn theo).
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: widget.embedded
          ? CompositedTransformFollower(
              link: _searchLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              child: panel,
            )
          : panel,
    );
  }

  Future<void> _pickDepartment() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(children: [
          const SizedBox(height: 12),
          const Text('Lọc theo phòng ban',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          Expanded(
            child: ListView(children: [
              ListTile(
                leading: const Icon(Icons.apps),
                title: const Text('Tất cả phòng ban'),
                selected: _departmentId == null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final d in _departments)
                ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(d.name),
                  selected: _departmentId == d.id,
                  trailing: _departmentId == d.id
                      ? const Icon(Icons.check, color: kFbBlue)
                      : null,
                  onTap: () => Navigator.pop(ctx, d.id),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked == null) return; // đóng sheet mà không chọn
    setState(() => _departmentId = picked.isEmpty ? null : picked);
    _reloadFromTop();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (r == null) return;
    setState(() {
      _fromDate = r.start;
      _toDate = r.end;
    });
    _reloadFromTop();
  }

  void _clearDate() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _reloadFromTop();
  }

  void _clearDepartment() {
    setState(() => _departmentId = null);
    _reloadFromTop();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String? get _departmentLabel {
    for (final d in _departments) {
      if (d.id == _departmentId) return d.name;
    }
    return _departmentId;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    // Các phần đầu danh sách
    final headers = <Widget>[
      if (widget.embedded) _searchBar(),
      if (widget.onCompose != null) _composer(),
      _sortChips(),
      _filterBar(),
    ];

    final list = RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: headers.length + _posts.length + 1,
        itemBuilder: (context, index) {
          if (index < headers.length) return headers[index];
          final postIndex = index - headers.length;
          if (postIndex < _posts.length) {
            final p = _posts[postIndex];
            return PostCard(
              key: ValueKey(p.id),
              post: p,
              onReact: (t) => _react(p, t),
              onShowReactors: () => showReactorsSheet(
                context,
                () => widget.service.getPostReactors(p.id),
                onTapUser: (r) => _showUser(r.userId, r.userName),
              ),
              onOpen: () => _openDetail(p),
              onReport: (widget.canReport && !_isAdmin) ? () => _reportPost(p) : null,
              reported: _reportedPosts.contains(p.id),
              onToggleHidden: _isAdmin ? () => _toggleHidden(p) : null,
              onTapAuthor: () => _showUser(p.userId, p.userName),
              onTapDepartment: () => _showDepartment(p),
            );
          }
          return _footer();
        },
      ),
    );

    // Hộp gợi ý vẽ đè lên danh sách
    final body = Stack(
      fit: StackFit.expand,
      children: [list, _suggestOverlay()],
    );

    if (widget.embedded) {
      return Container(color: kFbBg, child: body);
    }

    return Scaffold(
      backgroundColor: kFbBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: _searching
            ? TextField(
                controller: _searchCtl,
                focusNode: _searchFocus,
                onTapOutside: (_) => _hideSuggest(),
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: _submitSearch,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm bài viết',
                  border: InputBorder.none,
                ),
              )
            : const Text('Diễn đàn UTE',
                style: TextStyle(
                    color: kFbBlue, fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: kFbBg,
              child: Icon(_searching ? Icons.close : Icons.search, color: Colors.black87),
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _searchBar() =>
      CompositedTransformTarget(link: _searchLink, child: _searchBarBody());

  Widget _searchBarBody() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: TextField(
          controller: _searchCtl,
          focusNode: _searchFocus,
          onTapOutside: (_) => _hideSuggest(),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: _submitSearch,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm bài viết (gõ từng chữ, không cần dấu)',
            prefixIcon: const Icon(Icons.search, color: kFbText2),
            suffixIcon: _searchCtl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: kFbText2),
                    onPressed: _clearSearch,
                  ),
            filled: true,
            fillColor: kFbBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _composer() => Container(
        color: Colors.white,
        margin: EdgeInsets.only(top: widget.embedded ? 1 : 0),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          InitialAvatar(
              name: widget.currentUserName.isEmpty ? '?' : widget.currentUserName),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onCompose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text('Bạn muốn góp ý điều gì?',
                    style: TextStyle(color: kFbText2, fontSize: 15)),
              ),
            ),
          ),
        ]),
      );

  Widget _sortChips() => Container(
        color: Colors.white,
        margin: const EdgeInsets.only(top: 8),
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _sorts.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _sortBy == e.key,
                      selectedColor: const Color(0xFFE7F3FF),
                      labelStyle: TextStyle(
                        color: _sortBy == e.key ? kFbBlue : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        _sortBy = e.key;
                        _reloadFromTop();
                      },
                    ),
                  ))
              .toList(),
        ),
      );

  /// Hàng lọc: phòng ban + khoảng ngày (bấm dấu x trên chip để bỏ lọc).
  Widget _filterBar() {
    final hasDept = _departmentId != null;
    final hasDate = _fromDate != null && _toDate != null;
    const selColor = Color(0xFFE7F3FF);
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        children: [
          InputChip(
            avatar: Icon(Icons.apartment_outlined,
                size: 18, color: hasDept ? kFbBlue : Colors.black54),
            label: Text(hasDept ? (_departmentLabel ?? 'Phòng ban') : 'Phòng ban'),
            selected: hasDept,
            showCheckmark: false,
            selectedColor: selColor,
            labelStyle: TextStyle(
                color: hasDept ? kFbBlue : Colors.black87, fontWeight: FontWeight.w600),
            onPressed: _pickDepartment,
            onDeleted: hasDept ? _clearDepartment : null,
          ),
          const SizedBox(width: 8),
          InputChip(
            avatar: Icon(Icons.date_range,
                size: 18, color: hasDate ? kFbBlue : Colors.black54),
            label: Text(hasDate
                ? (_fromDate == _toDate
                    ? _fmt(_fromDate!)
                    : '${_fmt(_fromDate!)} – ${_fmt(_toDate!)}')
                : 'Khoảng ngày'),
            selected: hasDate,
            showCheckmark: false,
            selectedColor: selColor,
            labelStyle: TextStyle(
                color: hasDate ? kFbBlue : Colors.black87, fontWeight: FontWeight.w600),
            onPressed: _pickDateRange,
            onDeleted: hasDate ? _clearDate : null,
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: () => _load(), child: const Text('Thử lại')),
        ]),
      );
    }
    if (_posts.isEmpty && !_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _hasQuery ? 'Không tìm thấy bài viết phù hợp' : 'Chưa có bài viết nào',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kFbText2),
          ),
        ),
      );
    }
    if (_hasMore) {
      // Dự phòng: tự tải khi cuộn tới gần cuối, nút này dành cho trường hợp không tự tải được
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: TextButton(onPressed: () => _load(), child: const Text('Tải thêm bài viết')),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: Text('Bạn đã xem hết bài viết', style: TextStyle(color: kFbText2))),
    );
  }
}