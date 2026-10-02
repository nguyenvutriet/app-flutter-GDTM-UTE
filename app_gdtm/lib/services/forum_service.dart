// lib/services/forum_service.dart
// Port RequestService.getPublicPosts / getPostDetail / getFilteredPosts /
// getPublicSearchPosts / votePost + bình luận (thêm, trả lời, xóa, reaction) sang Firestore.
// Giữ nguyên schema phẳng hiện có: requests, comments, votes, votecomments...
// Mọi hàm đều yêu cầu đăng nhập.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Comment.dart';
import 'package:app_gdtm/models/VoteId.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/RequestService.dart';

class ForumException implements Exception {
  final String message;
  ForumException(this.message);
  @override
  String toString() => message;
}

class ForumService {
  // ------------------------------------------------------------
  // TODO: đối chiếu tên collection thực tế trên Firestore
  // (requests đã khớp với RequestService; các tên còn lại là suy đoán)
  // ------------------------------------------------------------
  static const String requestsCollection = RequestService.requestsCollection;
  static const String attachmentsCollection = RequestService.fileAttachmentsCollection;
  static const String commentsCollection = 'comment'; // chưa thấy trên Firestore (collection chỉ xuất hiện sau khi có bình luận đầu tiên)
  static const String votesCollection = 'vote';
  static const String voteCommentsCollection = 'votecomment';
  static const String usersCollection = 'users'; // doc id = Users.id
  static const String departmentsCollection = 'department';
  static const String categoriesCollection = 'categories';
  static const String commentReportsCollection = 'commentreport';

  static const int _whereInLimit = 30;

  final FirebaseFirestore _db;
  final String? Function() _getCurrentUserId;

  /// [currentUserId]: trả về Users.id của người đang đăng nhập (null nếu chưa đăng nhập).
  /// Ví dụ: ForumService(currentUserId: () => FirebaseAuth.instance.currentUser?.uid)
  /// — nếu Users.id của bạn khác Firebase uid thì lấy từ AuthService.
  ForumService({
    required String? Function() currentUserId,
    FirebaseFirestore? db,
  })  : _getCurrentUserId = currentUserId,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final id = _getCurrentUserId();
    if (id == null || id.isEmpty) throw ForumException('Chưa đăng nhập!');
    return id;
  }

  // Cache danh mục / phòng ban (ít thay đổi)
  Map<String, String>? _departmentNames;
  Map<String, String>? _categoryNames;

  // ==================================================================
  // BÀI VIẾT
  // ==================================================================

  /// getPublicPosts + sắp xếp (Strategy).
  /// Cần composite index: postStatus (asc) + timeCreate (desc) — Firestore sẽ in link tạo index.
  Future<PostPage> getPublicPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
    String sortBy = 'newest',
  }) async {
    final uid = _uid;
    Query<Map<String, dynamic>> q = _db
        .collection(requestsCollection)
        .where('postStatus', isEqualTo: RequestService.postStatusPublic)
        .orderBy('timeCreate', descending: true)
        .limit(limit);
    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final posts = await _buildPosts(snap.docs, uid);
    return PostPage(
      posts: _sort(sortBy, posts),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  /// getPostDetail (kèm cây bình luận) — null nếu không tồn tại.
  Future<ForumPostDTO?> getPostDetail(String postId) async {
    final uid = _uid;
    final doc = await _db.collection(requestsCollection).doc(postId).get();
    if (!doc.exists) return null;
    final posts = await _buildPosts([doc], uid, withComments: true);
    return posts.first;
  }

  /// getFilteredPosts. Sắp xếp phía client để không cần index cho từng tổ hợp filter.
  Future<List<ForumPostDTO>> getFilteredPosts({
    String? categoryId,
    String? departmentId,
    String sortBy = 'newest',
    int limit = 100,
  }) async {
    final uid = _uid;
    Query<Map<String, dynamic>> q = _db
        .collection(requestsCollection)
        .where('postStatus', isEqualTo: RequestService.postStatusPublic);
    if (departmentId != null && departmentId.trim().isNotEmpty) {
      q = q.where('departmentId', isEqualTo: departmentId);
    }
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      q = q.where('categoryIds', arrayContains: categoryId);
    }
    final snap = await q.limit(limit).get();
    final posts = await _buildPosts(snap.docs, uid);
    return _sort(sortBy, posts);
  }

  /// getPublicSearchPosts. Firestore không có full-text search nên lọc phía client
  /// trên [scanLimit] bài mới nhất.
  Future<List<ForumPostDTO>> searchPublicPosts(
    String keyword, {
    String sortBy = 'newest',
    int scanLimit = 200,
  }) async {
    final uid = _uid;
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return [];

    final snap = await _db
        .collection(requestsCollection)
        .where('postStatus', isEqualTo: RequestService.postStatusPublic)
        .orderBy('timeCreate', descending: true)
        .limit(scanLimit)
        .get();

    final matched = snap.docs.where((d) {
      final m = d.data();
      return (m['subject']?.toString() ?? '').toLowerCase().contains(kw) ||
          (m['description']?.toString() ?? '').toLowerCase().contains(kw);
    }).toList();

    return _sort(sortBy, await _buildPosts(matched, uid));
  }

  /// votePost: cùng loại thì bỏ, khác loại thì đổi, chưa có thì tạo.
  /// Doc id = "{userId}_{requestId}" để toggle trong transaction và không bị trùng vote.
  Future<VoteResult> votePost(String postId, String type) async {
    final uid = _uid;
    final t = _validType(type);
    final ref = _db.collection(votesCollection).doc('${uid}_$postId');

    final current = await _toggle(ref, t, () => {
          // Khớp Vote.toFirestore()
          'id': VoteId(userId: uid, requestId: postId).toJson(),
          'reactionType': t,
          'requestId': postId,
          'userId': uid,
          'voteAt': Timestamp.now(),
        });

    final snap = await _db
        .collection(votesCollection)
        .where('requestId', isEqualTo: postId)
        .get();
    return VoteResult(
      counts: countReactions(snap.docs.map((d) => d.data()['reactionType'])),
      currentType: current,
    );
  }

  // ==================================================================
  // BÌNH LUẬN
  // ==================================================================

  /// Danh sách bình luận dạng cây: bình luận gốc + replies (parentId).
  Future<List<CommentDTO>> getComments(String postId) async {
    final uid = _uid;
    final snap = await _db
        .collection(commentsCollection)
        .where('requestId', isEqualTo: postId)
        .get();
    return _commentTree(snap.docs, uid);
  }

  /// Thêm bình luận. Truyền [replyTo] để trả lời một bình luận:
  /// parentId = bình luận gốc, replyId = bình luận được trả lời trực tiếp.
  Future<CommentDTO> addComment(
    String postId,
    String content, {
    CommentDTO? replyTo,
  }) async {
    final uid = _uid;
    final text = content.trim();
    if (text.isEmpty) throw ForumException('Nội dung bình luận không được để trống');

    final ref = _db.collection(commentsCollection).doc();
    final now = DateTime.now();

    final comment = Comment(
      id: ref.id,
      content: text,
      date: now,
      isActive: true,
      parentId: replyTo == null ? null : (replyTo.parentId ?? replyTo.id),
      replyId: replyTo?.id,
      replyToUserId: replyTo?.userId,
      replyToUsername: replyTo?.userName,
      requestId: postId,
      userId: uid,
    );
    await ref.set(comment.toFirestore());

    final users = await _loadUsers({uid});
    final u = users[uid];
    return CommentDTO(
      id: ref.id,
      userId: uid,
      content: text,
      userName: _userName(u),
      userRole: _userRole(u),
      date: now,
      canDelete: true,
      parentId: comment.parentId,
      replyId: comment.replyId,
      replyToUserId: comment.replyToUserId,
      replyToUsername: comment.replyToUsername,
      reactions: countReactions(const []),
    );
  }

  /// Xóa mềm (isActive = false); chỉ chủ bình luận được xóa.
  /// Nếu là bình luận gốc thì các reply cũng bị ẩn.
  Future<void> deleteComment(String commentId) async {
    final uid = _uid;
    final ref = _db.collection(commentsCollection).doc(commentId);
    final doc = await ref.get();
    if (!doc.exists) return;
    if (doc.data()?['userId'] != uid) {
      throw ForumException('Bạn không có quyền xóa bình luận này');
    }

    final replies = await _db
        .collection(commentsCollection)
        .where('parentId', isEqualTo: commentId)
        .get();

    final batch = _db.batch();
    batch.update(ref, {'isActive': false});
    for (final r in replies.docs) {
      batch.update(r.reference, {'isActive': false});
    }
    await batch.commit();
  }

  /// Báo cáo bình luận. Doc id = "{userId}_{commentId}" nên mỗi người chỉ báo cáo
  /// một bình luận được đúng 1 lần (kiểm tra trong transaction).
  /// Quản trị viên không được báo cáo (họ là người duyệt).
  Future<void> reportComment(String commentId, String reason) async {
    final uid = _uid;

    final me = (await _loadUsers({uid}))[uid];
    if (_userRole(me).toUpperCase().contains('ADMIN')) {
      throw ForumException('Quản trị viên không thể báo cáo bình luận');
    }

    final text = reason.trim();
    if (text.isEmpty) throw ForumException('Vui lòng chọn lý do báo cáo');

    final cDoc = await _db.collection(commentsCollection).doc(commentId).get();
    if (!cDoc.exists) throw ForumException('Bình luận không còn tồn tại');
    if (cDoc.data()?['userId'] == uid) {
      throw ForumException('Bạn không thể báo cáo bình luận của chính mình');
    }

    final ref = _db.collection(commentReportsCollection).doc('${uid}_$commentId');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) throw ForumException('Bạn đã báo cáo bình luận này rồi');
      tx.set(ref, {
        'id': ref.id,
        'reason': text,
        'status': 'pending',
        'commentId': commentId,
        'studentId': uid,
        'createdAt': Timestamp.now(),
      });
    });
  }

  /// Reaction cho bình luận (VoteComment). Doc id = "{userId}_{commentId}".
  Future<VoteResult> voteComment(String commentId, String type) async {
    final uid = _uid;
    final t = _validType(type);
    final ref = _db.collection(voteCommentsCollection).doc('${uid}_$commentId');

    final current = await _toggle(ref, t, () => {
          // Khớp VoteComment.toFirestore()
          'reactionType': t,
          'commentId': commentId,
          'userId': uid,
          'voteAt': Timestamp.now(),
        });

    final snap = await _db
        .collection(voteCommentsCollection)
        .where('commentId', isEqualTo: commentId)
        .get();
    return VoteResult(
      counts: countReactions(snap.docs.map((d) => d.data()['reactionType'])),
      currentType: current,
    );
  }

  /// Danh sách người đã thả reaction cho bài viết (mới nhất trước).
  Future<List<ReactorDTO>> getPostReactors(String postId) =>
      _loadReactors(votesCollection, 'requestId', postId);

  /// Danh sách người đã thả reaction cho bình luận (mới nhất trước).
  Future<List<ReactorDTO>> getCommentReactors(String commentId) =>
      _loadReactors(voteCommentsCollection, 'commentId', commentId);

  Future<List<ReactorDTO>> _loadReactors(
    String collection,
    String field,
    String targetId,
  ) async {
    _uid; // bắt buộc đăng nhập
    final snap =
        await _db.collection(collection).where(field, isEqualTo: targetId).get();
    final votes = snap.docs.map((d) => d.data()).toList();
    final users = await _loadUsers(
        votes.map((v) => v['userId']).whereType<String>().toSet());

    final list = votes.map((v) {
      final id = v['userId']?.toString() ?? '';
      return ReactorDTO(
        userId: id,
        userName: _userName(users[id]),
        userRole: _userRole(users[id]),
        type: (v['reactionType']?.toString() ?? 'LIKE').toUpperCase(),
        date: (v['voteAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
    list.sort((a, b) => _cmpDate(b.date, a.date));
    return list;
  }

  // ==================================================================
  // NỘI BỘ
  // ==================================================================

  String _validType(String type) {
    final t = type.toUpperCase();
    if (!kReactionTypes.contains(t)) throw ForumException('Loại reaction không hợp lệ!');
    return t;
  }

  /// Toggle trong transaction. Trả về loại reaction hiện tại (null nếu đã bỏ).
  Future<String?> _toggle(
    DocumentReference<Map<String, dynamic>> ref,
    String type,
    Map<String, dynamic> Function() buildData,
  ) {
    return _db.runTransaction<String?>((tx) async {
      final snap = await tx.get(ref);
      final old = snap.data()?['reactionType']?.toString().toUpperCase();
      if (snap.exists && old == type) {
        tx.delete(ref);
        return null;
      }
      tx.set(ref, buildData());
      return type;
    });
  }

  /// convertToFullDTO (Java), gom dữ liệu theo lô (whereIn) thay vì truy vấn từng bài.
  Future<List<ForumPostDTO>> _buildPosts(
    List<DocumentSnapshot<Map<String, dynamic>>> docs,
    String uid, {
    bool withComments = false,
  }) async {
    if (docs.isEmpty) return [];
    await _ensureLookups();

    final ids = docs.map((d) => d.id).toList();
    final authorIds =
        docs.map((d) => d.data()?['userId']).whereType<String>().toSet();

    final votesF = _whereIn(votesCollection, 'requestId', ids);
    final commentsF = _whereIn(commentsCollection, 'requestId', ids);
    final attachF = _whereIn(attachmentsCollection, 'requestId', ids);
    final usersF = _loadUsers(authorIds);

    final votesBy = _groupBy(await votesF, 'requestId');
    final commentDocs = await commentsF;
    final commentsBy = _groupBy(commentDocs, 'requestId');
    final attachBy = _groupBy(await attachF, 'requestId');
    final users = await usersF;

    final tree = withComments ? await _commentTree(commentDocs, uid) : <CommentDTO>[];

    return docs.map((d) {
      final m = d.data() ?? {};
      final votes = votesBy[d.id] ?? const [];

      String? mine;
      for (final v in votes) {
        if (v['userId'] == uid) {
          mine = v['reactionType']?.toString().toUpperCase();
          break;
        }
      }

      final activeComments = (commentsBy[d.id] ?? const []).where(_isActive).length;

      return ForumPostDTO(
        id: d.id,
        subject: m['subject']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        status: m['currentStatus']?.toString(),
        date: (m['timeCreate'] as Timestamp?)?.toDate(),
        departmentName: _departmentNames![m['departmentId']] ?? 'N/A',
        userName: _userName(users[m['userId']]),
        categories: (m['categoryIds'] as List? ?? [])
            .map((id) => _categoryNames![id.toString()] ?? id.toString())
            .toList(),
        commentCount: activeComments,
        reactionType: mine,
        reactions: countReactions(votes.map((v) => v['reactionType'])),
        attachments: (attachBy[d.id] ?? const [])
            .map((a) => AttachmentDTO(
                  fileName: (a['filename'] ?? a['fileName'] ?? '').toString(),
                  fileUrl: (a['fileUrl'] ?? a['fileurl'] ?? '').toString(),
                  fileType: (a['filestype'] ?? a['fileType'] ?? '').toString(),
                ))
            .toList(),
        comments: tree,
      );
    }).toList();
  }

  /// Dựng cây bình luận: gốc (parentId rỗng) + replies, cũ → mới.
  Future<List<CommentDTO>> _commentTree(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) async {
    final active = docs.where((d) => _isActive(d.data())).toList();
    if (active.isEmpty) return [];

    final ids = active.map((d) => d.id).toList();
    final votesF = _whereIn(voteCommentsCollection, 'commentId', ids);
    final usersF = _loadUsers(
        active.map((d) => d.data()['userId']).whereType<String>().toSet());
    final votesBy = _groupBy(await votesF, 'commentId');
    final users = await usersF;

    CommentDTO toDto(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final m = d.data();
      final votes = votesBy[d.id] ?? const [];
      String? mine;
      for (final v in votes) {
        if (v['userId'] == uid) {
          mine = v['reactionType']?.toString().toUpperCase();
          break;
        }
      }
      final u = users[m['userId']];
      final parent = m['parentId']?.toString();
      return CommentDTO(
        id: d.id,
        userId: m['userId']?.toString() ?? '',
        content: m['content']?.toString() ?? '',
        userName: _userName(u),
        userRole: _userRole(u),
        date: (m['date'] as Timestamp?)?.toDate(),
        canDelete: m['userId'] == uid,
        parentId: (parent == null || parent.isEmpty) ? null : parent,
        replyId: m['replyId']?.toString(),
        replyToUserId: m['replyToUserId']?.toString(),
        replyToUsername: m['replyToUsername']?.toString(),
        reactions: countReactions(votes.map((v) => v['reactionType'])),
        reactionType: mine,
      );
    }

    final flat = active.map(toDto).toList()..sort((a, b) => _cmpDate(a.date, b.date));

    final repliesBy = <String, List<CommentDTO>>{};
    for (final c in flat.where((c) => c.isReply)) {
      repliesBy.putIfAbsent(c.parentId!, () => []).add(c);
    }

    // Admin (đỏ) → giảng viên (xanh) → còn lại; cùng nhóm thì cũ → mới
    int byPriority(CommentDTO a, CommentDTO b) {
      final p = a.rolePriority.compareTo(b.rolePriority);
      return p != 0 ? p : _cmpDate(a.date, b.date);
    }

    for (final list in repliesBy.values) {
      list.sort(byPriority);
    }

    return flat
        .where((c) => !c.isReply)
        .map((c) => c.copyWith(replies: repliesBy[c.id] ?? const []))
        .toList()
      ..sort(byPriority);
  }

  // ---------------- Truy vấn theo lô ----------------

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _whereIn(
    String collection,
    String field,
    List<String> ids,
  ) async {
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < ids.length; i += _whereInLimit) {
      final chunk = ids.sublist(i, i + _whereInLimit > ids.length ? ids.length : i + _whereInLimit);
      final snap = await _db.collection(collection).where(field, whereIn: chunk).get();
      out.addAll(snap.docs);
    }
    return out;
  }

  Map<String, List<Map<String, dynamic>>> _groupBy(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final d in docs) {
      final data = d.data();
      final key = data[field]?.toString();
      if (key != null) map.putIfAbsent(key, () => []).add(data);
    }
    return map;
  }

  /// Tải thông tin người dùng theo Users.id.
  /// Hỗ trợ cả hai kiểu lưu: doc id = Users.id, hoặc doc id bất kỳ + field 'id' = Users.id.
  Future<Map<String, Map<String, dynamic>>> _loadUsers(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    for (var i = 0; i < list.length; i += _whereInLimit) {
      final chunk = list.sublist(i, i + _whereInLimit > list.length ? list.length : i + _whereInLimit);
      final byDocId = _db
          .collection(usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final byField =
          _db.collection(usersCollection).where('id', whereIn: chunk).get();

      for (final d in (await byDocId).docs) {
        out[d.id] = d.data();
      }
      for (final d in (await byField).docs) {
        final key = d.data()['id']?.toString();
        if (key != null) out.putIfAbsent(key, () => d.data());
      }
    }
    return out;
  }

  Future<void> _ensureLookups() async {
    if (_departmentNames != null && _categoryNames != null) return;
    final results = await Future.wait([
      _db.collection(departmentsCollection).get(),
      _db.collection(categoriesCollection).get(),
    ]);
    _departmentNames = {
      for (final d in results[0].docs)
        d.id: (d.data()['name'] ?? d.data()['departmentName'] ?? '').toString()
    };
    _categoryNames = {
      for (final d in results[1].docs)
        d.id: (d.data()['subject'] ?? d.data()['name'] ?? '').toString()
    };
  }

  // ---------------- Tiện ích ----------------

  bool _isActive(Map<String, dynamic> m) => m['isActive'] != false;

  String _userName(Map<String, dynamic>? u) {
    final n = u?['fullName'] ??
        u?['fullname'] ??
        u?['full_name'] ??
        u?['name'] ??
        u?['displayName'] ??
        u?['hoTen'];
    return (n == null || n.toString().isEmpty) ? 'Ẩn danh' : n.toString();
  }

  String _userRole(Map<String, dynamic>? u) =>
      (u?['role']?.toString().isNotEmpty ?? false) ? u!['role'].toString() : 'ROLE_STUDENT';

  int _cmpDate(DateTime? a, DateTime? b) => (a ?? DateTime.fromMillisecondsSinceEpoch(0))
      .compareTo(b ?? DateTime.fromMillisecondsSinceEpoch(0));

  // Strategy sort (thay ForumSortContext) — chỉnh theo các strategy thật của bạn
  List<ForumPostDTO> _sort(String sortBy, List<ForumPostDTO> posts) {
    final list = [...posts];
    switch (sortBy) {
      case 'oldest':
        list.sort((a, b) => _cmpDate(a.date, b.date));
        break;
      case 'mostReactions':
        list.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
        break;
      case 'mostComments':
        list.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        break;
      case 'newest':
      default:
        list.sort((a, b) => _cmpDate(b.date, a.date));
    }
    return list;
  }
}