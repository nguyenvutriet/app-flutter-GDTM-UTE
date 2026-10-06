// lib/pages/student/forum_page.dart
// Bảng tin diễn đàn kiểu Facebook: tìm kiếm, sắp xếp, cuộn vô hạn, kéo để làm mới.
// embedded = true: dùng bên trong AppShell (không có Scaffold/AppBar riêng).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400 &&
          _hasMore &&
          !_loading &&
          _keyword.isEmpty) {
        _load();
      }
    });
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
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
      if (_keyword.isNotEmpty) {
        final r = await widget.service.searchPublicPosts(_keyword, sortBy: _sortBy);
        if (!mounted) return;
        setState(() {
          _posts = r;
          _hasMore = false;
        });
      } else {
        final page = await widget.service.getPublicPosts(startAfter: _last, sortBy: _sortBy);
        if (!mounted) return;
        setState(() {
          _posts = [..._posts, ...page.posts];
          _last = page.lastDoc ?? _last;
          _hasMore = page.hasMore;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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

  void _submitSearch(String v) {
    _keyword = v.trim();
    _load(reset: true);
  }

  void _clearSearch() {
    _searchCtl.clear();
    _keyword = '';
    _load(reset: true);
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _keyword.isNotEmpty) _clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    // Các phần đầu danh sách
    final headers = <Widget>[
      if (widget.embedded) _searchBar(),
      if (widget.onCompose != null) _composer(),
      _sortChips(),
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
                  context, () => widget.service.getPostReactors(p.id)),
              onOpen: () => _openDetail(p),
              onReport: (widget.canReport && !_isAdmin) ? () => _reportPost(p) : null,
              reported: _reportedPosts.contains(p.id),
              onToggleHidden: _isAdmin ? () => _toggleHidden(p) : null,
            );
          }
          return _footer();
        },
      ),
    );

    if (widget.embedded) {
      return Container(color: kFbBg, child: list);
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
                autofocus: true,
                textInputAction: TextInputAction.search,
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
      body: list,
    );
  }

  Widget _searchBar() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: TextField(
          controller: _searchCtl,
          textInputAction: TextInputAction.search,
          onSubmitted: _submitSearch,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm bài viết',
            prefixIcon: const Icon(Icons.search, color: kFbText2),
            suffixIcon: _keyword.isEmpty
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
                        _load(reset: true);
                      },
                    ),
                  ))
              .toList(),
        ),
      );

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
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _keyword.isEmpty ? 'Chưa có bài viết nào' : 'Không tìm thấy bài viết phù hợp',
            style: const TextStyle(color: kFbText2),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: Text('Bạn đã xem hết bài viết', style: TextStyle(color: kFbText2))),
    );
  }
}