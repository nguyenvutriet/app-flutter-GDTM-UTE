// lib/pages/student/post_detail_page.dart
// Chi tiết bài viết kiểu Facebook: bài viết + bình luận + trả lời + ô nhập cố định phía dưới.
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/comment_tile.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';
import 'package:app_gdtm/widgets/info_cards.dart';
import 'package:app_gdtm/widgets/post_card.dart';
import 'package:app_gdtm/widgets/reactors_sheet.dart';
import 'package:app_gdtm/widgets/report_comment_dialog.dart';

class PostDetailPage extends StatefulWidget {
  final ForumPostDTO initialPost;
  final ForumService service;

  /// Báo ngược về bảng tin khi reaction / số bình luận thay đổi
  final ValueChanged<ForumPostDTO>? onPostChanged;

  /// Cuộn tới và làm nổi bật bình luận này (admin bấm "Xem" từ trang báo cáo)
  final String? focusCommentId;

  /// false = ẩn nút "Báo cáo" (dùng cho admin)
  final bool canReport;

  const PostDetailPage({
    super.key,
    required this.initialPost,
    required this.service,
    this.onPostChanged,
    this.focusCommentId,
    this.canReport = true,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late ForumPostDTO _post;
  bool _loading = true;
  bool _sending = false;
  CommentDTO? _replyTo;

  /// Người dùng hiện tại là admin (thấy cả bình luận bị ẩn, được ẩn/hiện bình luận)
  bool _isAdmin = false;

  /// Id các bình luận người dùng này đã báo cáo
  final Set<String> _reported = {};
  bool _postReported = false;

  final Map<String, GlobalKey> _anchors = {};
  bool _scrolled = false;

  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setPost(ForumPostDTO p) {
    if (!mounted) return;
    setState(() => _post = p);
    widget.onPostChanged?.call(p);
  }

  int _total(List<CommentDTO> list) =>
      list.fold(0, (sum, c) => sum + 1 + c.replies.length);

  // ---------------- Card thông tin ----------------

  void _showUser(String userId, String name) =>
      showUserCard(context, widget.service, userId, fallbackName: name);

  void _showDepartment() => showDepartmentCard(
        context,
        widget.service,
        _post.departmentId,
        fallbackName: _post.departmentName,
      );

  Future<void> _refresh() async {
    try {
      _isAdmin = await widget.service.isAdmin();
      final p = await widget.service.getPostDetail(widget.initialPost.id);
      if (!mounted) return;
      if (p == null) {
        _snack('Bài viết không còn tồn tại hoặc đã bị ẩn');
        Navigator.pop(context);
        return;
      }
      _setPost(p);
      _loadReported();
      _scrollToFocus();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Cuộn tới bình luận được trỏ tới (nếu có).
  void _scrollToFocus() {
    final id = widget.focusCommentId;
    if (id == null || _scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final ctx = _anchors[id]?.currentContext;
      if (ctx == null) {
        _snack('Bình luận này đã bị ẩn hoặc không còn tồn tại');
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    });
  }

  Future<void> _reloadComments() async {
    final comments = await widget.service.getComments(_post.id);
    _setPost(_post.copyWith(comments: comments, commentCount: _total(comments)));
  }

  Future<void> _reactPost(String type) async {
    try {
      final r = await widget.service.votePost(_post.id, type);
      _setPost(_post.copyWith(
        reactions: r.counts,
        reactionType: r.currentType,
        clearReaction: r.currentType == null,
      ));
    } catch (e) {
      _snack(e.toString());
    }
  }

  List<CommentDTO> _mapTree(
    List<CommentDTO> list,
    String id,
    CommentDTO Function(CommentDTO) fn,
  ) =>
      list.map((c) {
        if (c.id == id) return fn(c);
        if (c.replies.isEmpty) return c;
        return c.copyWith(replies: _mapTree(c.replies, id, fn));
      }).toList();

  Future<void> _reactComment(CommentDTO c, String type) async {
    try {
      final r = await widget.service.voteComment(c.id, type);
      _setPost(_post.copyWith(
        comments: _mapTree(
          _post.comments,
          c.id,
          (x) => x.copyWith(
            reactions: r.counts,
            reactionType: r.currentType,
            clearReaction: r.currentType == null,
          ),
        ),
      ));
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _startReply(CommentDTO c) {
    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  /// Tải danh sách bình luận đã báo cáo (để hiện "Đã báo cáo"). Lỗi thì bỏ qua.
  Future<void> _loadReported() async {
    if (!widget.canReport || _isAdmin) return;
    try {
      final ids = await widget.service.getMyReportedCommentIds();
      final postIds = await widget.service.getMyReportedPostIds();
      if (mounted) {
        setState(() {
          _reported.addAll(ids);
          _postReported = postIds.contains(widget.initialPost.id);
        });
      }
    } catch (_) {}
  }

  /// Báo cáo bình luận vi phạm (mỗi người chỉ báo cáo 1 bình luận được 1 lần).
  Future<void> _reportComment(CommentDTO c) async {
    final reported = await showReportCommentDialog(
        context, service: widget.service, comment: c);
    if (reported && mounted) setState(() => _reported.add(c.id));
  }

  Future<void> _reportPost() async {
    final ok = await showReportPostDialog(context, service: widget.service, post: _post);
    if (ok && mounted) setState(() => _postReported = true);
  }

  Future<void> _toggleHiddenPost() async {
    final hide = !_post.isHidden;
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
      await widget.service.setPostHidden(_post.id, hidden: hide);
      _setPost(_post.copyWith(isHidden: hide));
      _snack(hide ? 'Đã ẩn bài viết' : 'Đã hiện lại bài viết');
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// Admin ẩn / hiện lại bình luận.
  Future<void> _toggleHidden(CommentDTO c) async {
    final hide = !c.isHidden;
    if (hide) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ẩn bình luận?'),
          content: const Text(
              'Bình luận (và các phản hồi bên dưới) sẽ không còn hiển thị với người dùng khác. '
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
      await widget.service.setCommentHidden(c.id, hidden: hide);
      await _reloadComments();
      _snack(hide ? 'Đã ẩn bình luận' : 'Đã hiện lại bình luận');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _deleteComment(CommentDTO c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bình luận (và các phản hồi của nó) sẽ bị ẩn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteComment(c.id);
      await _reloadComments();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.addComment(_post.id, text, replyTo: _replyTo);
      _ctl.clear();
      if (mounted) setState(() => _replyTo = null);
      await _reloadComments();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFbBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: Text('Bài viết của ${_post.userName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PostCard(
              post: _post,
              expanded: true,
              onReact: _reactPost,
              onShowReactors: () => showReactorsSheet(
                context,
                () => widget.service.getPostReactors(_post.id),
                onTapUser: (r) => _showUser(r.userId, r.userName),
              ),
              onTapComments: () => _focus.requestFocus(),
              onReport: (widget.canReport && !_isAdmin) ? _reportPost : null,
              reported: _postReported,
              onToggleHidden: _isAdmin ? _toggleHiddenPost : null,
              onTapAuthor: () => _showUser(_post.userId, _post.userName),
              onTapDepartment: _showDepartment,
            ),
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_post.isHidden)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4CC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Bài viết đang bị ẩn nên các bình luận cũng bị ẩn. '
                      'Hiện lại bài viết để ẩn/hiện từng bình luận.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                const Text('Bình luận',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_loading && _post.comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_post.comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Chưa có bình luận nào. Hãy là người đầu tiên!',
                          style: TextStyle(color: kFbText2)),
                    ),
                  )
                else
                  ..._post.comments.map((c) => CommentTile(
                        comment: c,
                        onReact: _reactComment,
                        onReply: _startReply,
                        onDelete: _deleteComment,
                        onTapUser: (c) => _showUser(c.userId, c.userName),
                        onReport: (widget.canReport && !_isAdmin) ? _reportComment : null,
                        reportedIds: _reported,
                        onToggleHidden: (_isAdmin && !_post.isHidden) ? _toggleHidden : null,
                        parentHidden: _post.isHidden,
                        highlightId: widget.focusCommentId,
                        anchors: _anchors,
                        onShowReactors: (c) => showReactorsSheet(
                          context,
                          () => widget.service.getCommentReactors(c.id),
                          onTapUser: (r) => _showUser(r.userId, r.userName),
                        ),
                      )),
              ]),
            ),
          ])),
        ),
        _inputBar(),
      ]),
    );
  }

  Widget _inputBar() => Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Divider(height: 1),
            if (_replyTo != null)
              Container(
                color: kFbBg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Text('Đang trả lời ${_replyTo!.userName}',
                        style: const TextStyle(color: kFbText2, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyTo = null),
                    child: const Icon(Icons.close, size: 18, color: kFbText2),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _replyTo == null
                          ? 'Viết bình luận...'
                          : 'Phản hồi ${_replyTo!.userName}...',
                      filled: true,
                      fillColor: kFbBg,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: kFbBlue),
                        onPressed: _send,
                      ),
              ]),
            ),
          ]),
        ),
      );
}