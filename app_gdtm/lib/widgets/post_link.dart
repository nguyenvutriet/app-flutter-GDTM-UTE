// lib/widgets/post_link.dart
// Liên kết bài viết: tạo link, sao chép, nhận diện link trong văn bản (bình luận, nội dung bài)
// và mở trang chi tiết bài viết.
//
// Dạng liên kết:  <địa chỉ app>/#/post/<requestId>
//   - Web: lấy địa chỉ hiện tại của app (localhost khi chạy thử, tên miền thật khi triển khai).
//   - Android / iOS: dùng [fallbackBaseUrl].
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';

class PostLink {
  /// TODO: đổi thành địa chỉ web thật của app (dùng khi sao chép link từ Android / iOS).
  static const String fallbackBaseUrl = 'https://flutter-giai-dap-thac-mac-app.web.app';

  /// Bắt mọi link dạng http(s)://.../#/post/<id>
  static final RegExp linkRegex = RegExp(r'https?://[^\s]*?#/post/([A-Za-z0-9_-]+)');
  static final RegExp _routeRegex = RegExp(r'^/?post/([A-Za-z0-9_-]+)');

  /// Hàm mở bài viết, do DashboardPage gán (có Navigator + ForumService).
  static void Function(String postId)? openHandler;

  static bool _captured = false;
  static String? _initialId;

  static String build(String postId) {
    final base = kIsWeb ? Uri.base.origin : fallbackBaseUrl;
    return '$base/#/post/$postId';
  }

  /// Lấy id bài viết từ đoạn văn bản chứa link (null nếu không có).
  static String? extractId(String text) => linkRegex.firstMatch(text)?.group(1);

  /// Ghi nhớ link mà người dùng đã mở app bằng nó (chỉ web).
  /// Nên gọi ở đầu main() trước runApp để chắc chắn bắt được.
  static void captureInitial() {
    if (_captured) return;
    _captured = true;
    if (!kIsWeb) return;
    final uri = Uri.base;
    _initialId = _routeRegex.firstMatch(uri.fragment)?.group(1) ??
        _routeRegex.firstMatch(uri.path)?.group(1);
  }

  /// Trả về id bài viết trong link mở app (chỉ trả một lần).
  static String? consumeInitialPostId() {
    captureInitial();
    final id = _initialId;
    _initialId = null;
    return id;
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  /// Sao chép link của bài viết.
  static Future<void> copy(BuildContext context, String postId) =>
      copyText(context, build(postId));

  /// Sao chép một đoạn văn bản (vd: link nằm trong bình luận).
  static Future<void> copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _toast(context, 'Đã sao chép liên kết bài viết');
  }

  /// Mở trang chi tiết bài viết từ id.
  static void open(BuildContext context, String postId) {
    final handler = openHandler;
    if (handler == null) {
      _toast(context, 'Không mở được bài viết.');
      return;
    }
    handler(postId);
  }
}

/// Tải bài viết để mở bằng link. Chỉ cho xem bài công khai.
Future<ForumPostDTO> fetchPublicPost(ForumService forum, String postId) async {
  final doc = await FirebaseFirestore.instance
      .collection(RequestService.requestsCollection)
      .doc(postId)
      .get();
  if (!doc.exists) {
    throw ForumException('Bài viết không tồn tại hoặc đã bị xóa.');
  }
  if (doc.data()?['postStatus'] != RequestService.postStatusPublic) {
    throw ForumException('Bài viết này không được công khai.');
  }
  if (doc.data()?['isHidden'] == true && !await forum.isAdmin()) {
    throw ForumException('Bài viết này đã bị ẩn.');
  }
  final post = await forum.getPostDetail(postId);
  if (post == null) {
    throw ForumException('Bài viết không tồn tại hoặc đã bị xóa.');
  }
  return post;
}

/// Tách văn bản thành các đoạn; link bài viết hiện thành "Xem bài viết"
/// (chạm = mở bài viết, nhấn giữ = sao chép link).
List<InlineSpan> linkifySpans(BuildContext context, String text) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in PostLink.linkRegex.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final url = m.group(0)!;
    final id = m.group(1)!;
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: () => PostLink.open(context, id),
        onLongPress: () => PostLink.copyText(context, url),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link, size: 16, color: kFbBlue),
          SizedBox(width: 2),
          Text(
            'Xem bài viết',
            style: TextStyle(
              color: kFbBlue,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ]),
      ),
    ));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  if (spans.isEmpty) spans.add(TextSpan(text: text));
  return spans;
}

// ====================================================================
// THẺ XEM TRƯỚC BÀI VIẾT (thay cho đường link thô trong bình luận)
// ====================================================================

class PostPreview {
  final String id;
  final String subject;
  final String description;
  final String authorName;
  final bool available;

  const PostPreview({
    required this.id,
    this.subject = '',
    this.description = '',
    this.authorName = '',
  }) : available = true;

  const PostPreview.unavailable(this.id)
      : subject = '',
        description = '',
        authorName = '',
        available = false;
}

final Map<String, Future<PostPreview>> _previewCache = {};

/// Tải tóm tắt bài viết (có nhớ tạm để không đọc lại nhiều lần).
Future<PostPreview> loadPostPreview(String postId) {
  return _previewCache.putIfAbsent(postId, () => _fetchPreview(postId));
}

Future<PostPreview> _fetchPreview(String postId) async {
  try {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection(RequestService.requestsCollection).doc(postId).get();
    final m = doc.data();
    if (!doc.exists ||
        m == null ||
        m['postStatus'] != RequestService.postStatusPublic ||
        m['isHidden'] == true) {      
      return PostPreview.unavailable(postId);
    }

    // Tên người đăng (users: doc id hoặc field 'id' = Users.id)
    var author = 'Ẩn danh';
    final uid = m['userId']?.toString();
    if (uid != null && uid.isNotEmpty) {
      var u = (await db.collection('users').doc(uid).get()).data();
      if (u == null) {
        final q = await db.collection('users').where('id', isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) u = q.docs.first.data();
      }
      final n = u?['fullName'] ?? u?['fullname'] ?? u?['name'];
      if (n != null && n.toString().isNotEmpty) author = n.toString();
    }

    return PostPreview(
      id: postId,
      subject: m['subject']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      authorName: author,
    );
  } catch (_) {
    _previewCache.remove(postId); // lỗi mạng: cho phép thử lại lần sau
    return PostPreview.unavailable(postId);
  }
}

/// Thẻ nhỏ xem trước bài viết. Chạm = mở bài viết, nhấn giữ = sao chép link.
class PostLinkCard extends StatelessWidget {
  final String postId;
  final String url;

  const PostLinkCard({super.key, required this.postId, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: FutureBuilder<PostPreview>(
          future: loadPostPreview(postId),
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final p = snap.data;

            Widget body;
            if (loading) {
              body = const Text('Đang tải bài viết...',
                  style: TextStyle(fontSize: 13, color: kFbText2));
            } else if (p == null || !p.available) {
              body = const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Bài viết không khả dụng',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Bài viết không tồn tại hoặc không công khai.',
                      style: TextStyle(fontSize: 12, color: kFbText2)),
                ],
              );
            } else {
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('DIỄN ĐÀN UTE',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 0.5, color: kFbText2)),
                  const SizedBox(height: 2),
                  Text(p.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: kFbText2)),
                  ],
                  const SizedBox(height: 4),
                  Text('Đăng bởi ${p.authorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: kFbText2)),
                ],
              );
            }

            return Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.black12),
              ),
              child: InkWell(
                onTap: () => PostLink.open(context, postId),
                onLongPress: () => PostLink.copyText(context, url),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      width: 44,
                      color: const Color(0xFFE7F3FF),
                      alignment: Alignment.center,
                      child: const Icon(Icons.article_outlined, color: kFbBlue),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: body,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hiển thị nội dung văn bản; mỗi link bài viết hiện thành [PostLinkCard].
/// [prefix]: tiền tố in xanh đậm (vd: "@tên người được trả lời ").
class LinkifiedContent extends StatelessWidget {
  final String text;
  final String? prefix;
  final TextStyle? style;

  const LinkifiedContent({super.key, required this.text, this.prefix, this.style});

  @override
  Widget build(BuildContext context) {
    const prefixStyle = TextStyle(color: kFbBlue, fontWeight: FontWeight.w600);
    final matches = PostLink.linkRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text.rich(
        TextSpan(children: [
          if (prefix != null) TextSpan(text: prefix, style: prefixStyle),
          TextSpan(text: text),
        ]),
        style: style,
      );
    }

    var pendingPrefix = prefix;
    final children = <Widget>[];

    void addText(String segment) {
      final s = segment.trim();
      if (s.isEmpty) return;
      children.add(Text.rich(
        TextSpan(children: [
          if (pendingPrefix != null) TextSpan(text: pendingPrefix, style: prefixStyle),
          TextSpan(text: s),
        ]),
        style: style,
      ));
      pendingPrefix = null;
    }

    var last = 0;
    for (final m in matches) {
      addText(text.substring(last, m.start));
      if (pendingPrefix != null) {
        children.add(Text(pendingPrefix!, style: prefixStyle.merge(style)));
        pendingPrefix = null;
      }
      children.add(PostLinkCard(postId: m.group(1)!, url: m.group(0)!));
      last = m.end;
    }
    addText(text.substring(last));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}