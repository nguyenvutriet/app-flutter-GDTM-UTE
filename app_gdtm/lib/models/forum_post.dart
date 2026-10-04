// lib/models/forum_post.dart
// View-model (tương đương ForumPostDTO / CommentDTO / AttachmentDTO bên Java).
// Khác với Request/Comment/Vote (model dữ liệu), các DTO này đã gộp sẵn tên người dùng,
// phòng ban, danh mục, số lượng reaction... để UI dùng trực tiếp.
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kReactionTypes = ['LIKE', 'LOVE', 'HAHA', 'WOW', 'SAD', 'ANGRY'];

const Map<String, String> kReactionEmoji = {
  'LIKE': '👍',
  'LOVE': '❤️',
  'HAHA': '😆',
  'WOW': '😮',
  'SAD': '😢',
  'ANGRY': '😡',
};

/// Đếm số lượng theo 6 loại reaction (luôn đủ 6 key, mặc định 0) — như reactionsMap bên Java.
Map<String, int> countReactions(Iterable<dynamic> types) {
  final r = {for (final k in kReactionTypes) k: 0};
  for (final t in types) {
    final k = t?.toString().toUpperCase();
    if (k != null && r.containsKey(k)) r[k] = r[k]! + 1;
  }
  return r;
}

class AttachmentDTO {
  final String fileName;
  final String fileUrl;
  final String fileType;

  const AttachmentDTO({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
  });
}

class CommentDTO {
  final String id;
  final String userId;
  final String content;
  final String userName;
  final String userRole;
  final DateTime? date;
  final bool canDelete;

  /// Bị admin ẩn (vi phạm). Chỉ admin mới nhận được bình luận loại này (hiển thị mờ).
  final bool isHidden;

  /// Cấu trúc reply: parentId = bình luận gốc, replyId = bình luận được trả lời trực tiếp
  final String? parentId;
  final String? replyId;
  final String? replyToUserId;
  final String? replyToUsername;
  final List<CommentDTO> replies;

  final Map<String, int> reactions;
  final String? reactionType;

  const CommentDTO({
    required this.id,
    required this.userId,
    required this.content,
    required this.userName,
    this.userRole = 'ROLE_STUDENT',
    this.date,
    this.canDelete = false,
    this.isHidden = false,
    this.parentId,
    this.replyId,
    this.replyToUserId,
    this.replyToUsername,
    this.replies = const [],
    this.reactions = const {},
    this.reactionType,
  });

  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);

  /// Tích xanh cho tài khoản không phải sinh viên
  bool get isVerified => userRole.isNotEmpty && !userRole.toUpperCase().contains('STUDENT');

  bool get isReply => parentId != null && parentId!.isNotEmpty;

  /// ROLE_ADMIN (hiện màu đỏ) và ROLE_TEACHER (hiện màu xanh) được ưu tiên lên đầu.
  bool get isAdmin => userRole.toUpperCase().contains('ADMIN');
  bool get isTeacher => userRole.toUpperCase().contains('TEACHER');

  /// 0 = admin, 1 = giảng viên, 2 = còn lại (số nhỏ hơn hiện trước)
  int get rolePriority => isAdmin ? 0 : (isTeacher ? 1 : 2);

  CommentDTO copyWith({
    Map<String, int>? reactions,
    String? reactionType,
    bool clearReaction = false,
    List<CommentDTO>? replies,
    bool? isHidden,
  }) =>
      CommentDTO(
        id: id,
        userId: userId,
        content: content,
        userName: userName,
        userRole: userRole,
        date: date,
        canDelete: canDelete,
        isHidden: isHidden ?? this.isHidden,
        parentId: parentId,
        replyId: replyId,
        replyToUserId: replyToUserId,
        replyToUsername: replyToUsername,
        replies: replies ?? this.replies,
        reactions: reactions ?? this.reactions,
        reactionType: clearReaction ? null : (reactionType ?? this.reactionType),
      );
}

class ForumPostDTO {
  final String id;
  final String subject;
  final String description;
  final String? status;
  final DateTime? date;
  final String departmentName;
  final String userName;
  final List<String> categories;
  final int commentCount;
  final String? reactionType;
  final Map<String, int> reactions;
  final List<AttachmentDTO> attachments;
  final List<CommentDTO> comments;
  final bool isHidden; //admin ẩn
  final bool isMine; // ko tự report bài của mình

  const ForumPostDTO({
    required this.id,
    required this.subject,
    required this.description,
    this.status,
    this.date,
    this.departmentName = 'N/A',
    this.userName = 'Ẩn danh',
    this.categories = const [],
    this.commentCount = 0,
    this.reactionType,
    this.reactions = const {},
    this.attachments = const [],
    this.comments = const [],
    this.isHidden = false,
    this.isMine = false,
  });

  String get reactionTypeLower => (reactionType ?? '').toLowerCase();

  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);

  /// Top 3 loại reaction nhiều nhất (getTopReactionIcons bên Java)
  List<String> get topReactionIcons {
    final entries = reactions.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(3)
        .map((e) => kReactionEmoji[e.key.toUpperCase()] ?? '👍')
        .toList();
  }

  ForumPostDTO copyWith({
    String? reactionType,
    bool clearReaction = false,
    Map<String, int>? reactions,
    int? commentCount,
    List<CommentDTO>? comments,
    bool ? isHidden,
  }) =>
      ForumPostDTO(
        id: id,
        subject: subject,
        description: description,
        status: status,
        date: date,
        departmentName: departmentName,
        userName: userName,
        categories: categories,
        commentCount: commentCount ?? this.commentCount,
        reactionType: clearReaction ? null : (reactionType ?? this.reactionType),
        reactions: reactions ?? this.reactions,
        attachments: attachments,
        comments: comments ?? this.comments,
        isHidden: isHidden ?? this.isHidden,
        isMine: isMine,
      );
}

/// Thay cho Page<ForumPostDTO>: phân trang bằng cursor của Firestore.
class PostPage {
  final List<ForumPostDTO> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const PostPage({required this.posts, this.lastDoc, this.hasMore = false});
}

/// Kết quả toggle reaction: counts + currentType (null nếu đã bỏ reaction)
class VoteResult {
  final Map<String, int> counts;
  final String? currentType;

  const VoteResult({required this.counts, this.currentType});

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Một người đã thả reaction (cho danh sách "ai đã thả reaction")
class ReactorDTO {
  final String userId;
  final String userName;
  final String type; // LIKE, LOVE, ...
  final DateTime? date;
  final String userRole;

  const ReactorDTO({
    required this.userId,
    required this.userName,
    required this.type,
    this.date,
    this.userRole = 'ROLE_STUDENT',
  });

  bool get isAdmin => userRole.toUpperCase().contains('ADMIN');
  bool get isTeacher => userRole.toUpperCase().contains('TEACHER');

  /// Tích xanh cho tài khoản không phải sinh viên (giống bình luận)
  bool get isVerified =>
      userRole.isNotEmpty && !userRole.toUpperCase().contains('STUDENT');
}