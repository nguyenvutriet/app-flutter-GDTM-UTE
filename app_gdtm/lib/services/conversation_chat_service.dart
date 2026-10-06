import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/FileAttachment.dart';

// ============================================================
// MODEL NHẸ DÙNG CHO HỘI THOẠI (viết mới, không đụng vào model cũ)
// ============================================================

/// Một cuộc trao đổi (document của collection `clarificationconversation`).
class ConversationInfo {
  /// Document ID - dùng làm khoá chính (field `id` trong dữ liệu mẫu có thể
  /// bị rỗng nên không tin cậy).
  final String docId;

  /// Giá trị field `id` (nếu có và khác Document ID).
  final String? idField;

  final String requestId;
  final String subject;
  final bool isOpen;
  final DateTime? createAt;

  const ConversationInfo({
    required this.docId,
    required this.idField,
    required this.requestId,
    required this.subject,
    required this.isOpen,
    required this.createAt,
  });

  /// Các giá trị `clarificationConversationId` có thể gắn với tin nhắn của
  /// cuộc trao đổi này (Document ID, và field `id` nếu khác).
  List<String> get messageKeys {
    final keys = <String>{docId};
    final alt = idField?.trim() ?? '';
    if (alt.isNotEmpty) keys.add(alt);
    return keys.toList();
  }

  factory ConversationInfo.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final idField = (data['id'] as String?)?.trim();
    return ConversationInfo(
      docId: doc.id,
      idField: (idField == null || idField.isEmpty || idField == doc.id)
          ? null
          : idField,
      requestId: (data['requestId'] as String?) ?? '',
      subject: ((data['subject'] as String?) ?? '').trim(),
      isOpen: data['isOpen'] == true,
      createAt: _toDate(data['createAt']),
    );
  }
}

/// Một tin nhắn (document của collection `message`).
class ConversationMessage {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final DateTime? createAt;
  final List<FileAttachment> attachments;

  const ConversationMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.createAt,
    this.attachments = const [],
  });

  factory ConversationMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ConversationMessage(
      id: doc.id,
      content: (data['content'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      createAt: _toDate(data['createAt']),
      attachments: (data['attachments'] as List?)
              ?.whereType<Map>()
              .map((item) => FileAttachment.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList() ??
          const [],
    );
  }
}

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

// ============================================================
// LỖI
// ============================================================

/// Lỗi hội thoại có thông báo tiếng Việt, hiển thị thẳng cho người dùng.
class ConversationChatException implements Exception {
  final String message;
  const ConversationChatException(this.message);

  @override
  String toString() => message;
}

/// Cuộc trao đổi đã bị đóng nên không gửi thêm tin nhắn được.
class ConversationClosedException extends ConversationChatException {
  const ConversationClosedException()
      : super('Cuộc trao đổi đã được đóng, không thể gửi thêm tin nhắn.');
}

// ============================================================
// SERVICE
// ============================================================

/// Hội thoại làm rõ góp ý giữa sinh viên và cán bộ, thời gian thực.
///
/// Dùng 2 collection có sẵn trên Firestore:
///   - `clarificationconversation`: createAt, id, isOpen, requestId, subject
///   - `message`: clarificationConversationId, content, createAt, id,
///                receiverId, senderId
///
/// Service viết chung (không gắn với role) để phía sinh viên có thể dùng lại.
class ConversationChatService {
  static const String conversationCollection = 'clarificationconversation';
  static const String messageCollection = 'message';
  static const String usersCollection = 'users';

  static const int maxSubjectLength = 100;
  static const int maxMessageLength = 1000;

  static const Duration _timeout = Duration(seconds: 20);

  static const String _networkError =
      'Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.';

  final FirebaseFirestore _firestore;

  ConversationChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection(conversationCollection);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection(messageCollection);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(usersCollection);

  // ------------------------------------------------------------
  // REALTIME
  // ------------------------------------------------------------

  /// Các cuộc trao đổi của một góp ý, mới nhất trước. Tự cập nhật theo thời
  /// gian thực (tạo mới, đóng trao đổi...).
  Stream<List<ConversationInfo>> watchConversations(String requestId) {
    return _conversations
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ConversationInfo.fromDoc).toList()
        ..sort(
          (a, b) => (b.createAt ?? DateTime(0)).compareTo(
            a.createAt ?? DateTime(0),
          ),
        );
      return list;
    });
  }

  /// Tin nhắn của một cuộc trao đổi, cũ nhất trước. Tự cập nhật theo thời
  /// gian thực. Sắp xếp ở phía app nên không cần tạo composite index.
  Stream<List<ConversationMessage>> watchMessages(
    ConversationInfo conversation,
  ) {
    final keys = conversation.messageKeys;
    final Query<Map<String, dynamic>> query = keys.length == 1
        ? _messages.where('clarificationConversationId', isEqualTo: keys.first)
        : _messages.where('clarificationConversationId', whereIn: keys);

    return query.snapshots().map((snap) {
      final list = snap.docs.map(ConversationMessage.fromDoc).toList()
        ..sort((a, b) {
          final byTime = (a.createAt ?? DateTime(0)).compareTo(
            b.createAt ?? DateTime(0),
          );
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
      return list;
    });
  }

  // ------------------------------------------------------------
  // MỞ HỘI THOẠI
  // ------------------------------------------------------------

  /// Tạo cuộc trao đổi mới cho góp ý [requestId] kèm tin nhắn đầu tiên
  /// (ghi cùng lúc bằng một batch: hoặc có cả hai, hoặc không có gì).
  Future<void> openConversation({
    required String requestId,
    required String subject,
    required String firstMessage,
    required String senderId,
    required String receiverId,
  }) async {
    final cleanSubject = subject.trim();
    final cleanMessage = firstMessage.trim();
    if (requestId.trim().isEmpty) {
      throw const ConversationChatException('Góp ý không hợp lệ.');
    }
    if (cleanSubject.isEmpty) {
      throw const ConversationChatException('Vui lòng nhập chủ đề.');
    }
    if (cleanMessage.isEmpty) {
      throw const ConversationChatException('Vui lòng nhập tin nhắn.');
    }
    if (receiverId.trim().isEmpty) {
      throw const ConversationChatException(
        'Góp ý này không có mã sinh viên nên không thể mở hội thoại.',
      );
    }

    try {
      // Chỉ chặn khi góp ý đang có một cuộc trao đổi mở. Các cuộc đã đóng
      // được giữ lại để xem lịch sử và có thể mở cuộc mới.
      final existing = await _conversations
          .where('requestId', isEqualTo: requestId)
          .get()
          .timeout(_timeout);
      final hasOpenConversation = existing.docs.any(
        (doc) => doc.data()['isOpen'] == true,
      );
      if (hasOpenConversation) {
        throw const ConversationChatException(
          'Góp ý này đang có một cuộc trao đổi mở.',
        );
      }

      final now = Timestamp.now();
      final conversationRef = _conversations.doc();
      final messageRef = _messages.doc();

      final batch = _firestore.batch();
      batch.set(conversationRef, {
        'id': conversationRef.id,
        'requestId': requestId,
        'subject': cleanSubject,
        'isOpen': true,
        'createAt': now,
      });
      batch.set(messageRef, {
        'id': messageRef.id,
        'clarificationConversationId': conversationRef.id,
        'content': cleanMessage,
        'senderId': senderId,
        'receiverId': receiverId,
        'createAt': now,
      });
      await batch.commit().timeout(_timeout);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    } on TimeoutException {
      throw const ConversationChatException(_networkError);
    }
  }

  // ------------------------------------------------------------
  // GỬI TIN NHẮN
  // ------------------------------------------------------------

  /// Gửi một tin nhắn. Kiểm tra `isOpen` và ghi tin nhắn trong cùng một
  /// transaction nên nếu cuộc trao đổi vừa bị đóng thì tin nhắn không được
  /// ghi, ném [ConversationClosedException].
  Future<void> sendMessage({
    required ConversationInfo conversation,
    required String senderId,
    required String receiverId,
    required String content,
    List<FileAttachment> attachments = const [],
  }) async {
    final text = content.trim();
    if (text.isEmpty && attachments.isEmpty) {
      throw const ConversationChatException(
        'Tin nhắn phải có nội dung hoặc tệp đính kèm.',
      );
    }
    if (text.length > maxMessageLength) {
      throw const ConversationChatException(
        'Tin nhắn tối đa $maxMessageLength ký tự.',
      );
    }

    final conversationRef = _conversations.doc(conversation.docId);
    final messageRef = _messages.doc();

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(conversationRef);
        if (!snap.exists) {
          throw const ConversationChatException(
            'Cuộc trao đổi không còn tồn tại.',
          );
        }
        if (snap.data()?['isOpen'] != true) {
          throw const ConversationClosedException();
        }
        tx.set(messageRef, {
          'id': messageRef.id,
          'clarificationConversationId': conversation.docId,
          'content': text,
          'senderId': senderId,
          'receiverId': receiverId,
          'createAt': Timestamp.now(),
          'attachments': attachments.map((file) => file.toFirestore()).toList(),
        });
      }).timeout(_timeout);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    } on TimeoutException {
      throw const ConversationChatException(_networkError);
    }
  }

  // ------------------------------------------------------------
  // ĐÓNG TRAO ĐỔI
  // ------------------------------------------------------------

  /// Đóng cuộc trao đổi: `isOpen = false`. Cả hai bên (sinh viên và cán bộ)
  /// đều chỉ xem được, không nhắn tiếp được.
  Future<void> closeConversation(ConversationInfo conversation) async {
    try {
      await _conversations
          .doc(conversation.docId)
          .update({'isOpen': false}).timeout(_timeout);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    } on TimeoutException {
      throw const ConversationChatException(_networkError);
    }
  }

  // ------------------------------------------------------------
  // TÊN NGƯỜI DÙNG
  // ------------------------------------------------------------

  final Map<String, String?> _nameCache = {};

  /// Họ tên của user theo mã (Document ID hoặc field `id` trong `users`).
  /// Trả về null nếu không tìm thấy. Có cache để không đọc lại nhiều lần.
  Future<String?> getUserName(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    if (_nameCache.containsKey(id)) return _nameCache[id];

    String? name;
    try {
      if (!id.contains('/')) {
        final byDocId = await _users.doc(id).get();
        if (byDocId.exists) name = _fullName(byDocId.data());
      }
      if (name == null) {
        final byField = await _users.where('id', isEqualTo: id).limit(1).get();
        if (byField.docs.isNotEmpty) {
          name = _fullName(byField.docs.first.data());
        }
      }
    } catch (_) {
      // Không đọc được thì hiển thị tên mặc định, không làm hỏng khung chat.
    }
    _nameCache[id] = name;
    return name;
  }

  String? _fullName(Map<String, dynamic>? data) {
    final name = (data?['fullName'] as String?)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  ConversationChatException _mapFirestoreError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return const ConversationChatException(
        'Không có quyền truy cập dữ liệu trao đổi. Hãy kiểm tra Firestore Rules.',
      );
    }
    if (e.code == 'unavailable') {
      return const ConversationChatException(_networkError);
    }
    return ConversationChatException(
      'Lỗi hệ thống (${e.code}). Vui lòng thử lại.',
    );
  }
}
