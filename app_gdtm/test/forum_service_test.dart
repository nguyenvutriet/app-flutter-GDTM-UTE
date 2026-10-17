// test/forum_service_test.dart
//
// Kiểm thử đơn vị tự động cho ForumService (10 hàm đã phân tích hộp trắng):
//   _uid, isAdmin, _validType, _toggle, addComment, deleteComment,
//   reportPost, setPostHidden, getUserInfo, getSuggestions
//
// Hàm private (_uid, _validType, _toggle) được kiểm thử gián tiếp qua hàm public:
//   _uid        -> isAdmin / getUserInfo / ... khi chưa đăng nhập
//   _validType  -> votePost với loại reaction hợp lệ / không hợp lệ
//   _toggle     -> votePost: tạo mới / bỏ (cùng loại) / đổi (khác loại)
//
// Chạy:  flutter test test/forum_service_test.dart
// Độ phủ: flutter test --coverage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_gdtm/models/forum_post.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/forum_service.dart';

/// Khớp một ForumException với đúng thông báo.
Matcher throwsForum(String message) => throwsA(
      isA<ForumException>().having((e) => e.message, 'message', message),
    );

void main() {
  late FakeFirebaseFirestore db;
  String? currentUid;

  // Mỗi test tạo service mới vì service có cache (admin, người dùng, phòng ban).
  ForumService build() => ForumService(currentUserId: () => currentUid, db: db);

  CollectionReference<Map<String, dynamic>> col(String name) =>
      db.collection(name);

  Future<Map<String, dynamic>?> docData(String collection, String id) async =>
      (await col(collection).doc(id).get()).data();

  Future<bool> docExists(String collection, String id) async =>
      (await col(collection).doc(id).get()).exists;

  Map<String, dynamic> post({
    required String subject,
    required String userId,
    required DateTime time,
    String departmentId = 'd1',
    bool hidden = false,
    String description = '',
  }) =>
      {
        'subject': subject,
        'description': description,
        'userId': userId,
        'departmentId': departmentId,
        'categoryIds': ['c1'],
        'postStatus': RequestService.postStatusPublic,
        'timeCreate': Timestamp.fromDate(time),
        'isHidden': hidden,
      };

  setUp(() async {
    db = FakeFirebaseFirestore();
    currentUid = 'u1';

    // Người dùng
    await col(ForumService.usersCollection).doc('admin1').set({
      'id': 'admin1',
      'fullName': 'Quản Trị',
      'email': 'admin@ute.edu.vn',
      'role': 'ROLE_ADMIN',
      'departmentId': 'd1',
    });
    await col(ForumService.usersCollection).doc('u1').set({
      'id': 'u1',
      'fullName': 'Nguyễn Văn A',
      'email': 'a@student.ute.edu.vn',
      'role': 'ROLE_STUDENT',
      'departmentId': 'd1',
    });
    await col(ForumService.usersCollection).doc('u2').set({
      'id': 'u2',
      'fullName': 'Trần Thị B',
      'email': 'b@student.ute.edu.vn',
      'role': 'ROLE_STUDENT',
    });
    // Người dùng thiếu tên và vai trò -> dùng giá trị mặc định
    await col(ForumService.usersCollection).doc('u4').set({
      'id': 'u4',
      'email': 'x@ute.edu.vn',
    });

    // Phòng ban, danh mục
    await col(ForumService.departmentsCollection)
        .doc('d1')
        .set({'name': 'Phòng Đào Tạo'});
    await col(ForumService.departmentsCollection)
        .doc('d2')
        .set({'name': 'Phòng Công Tác Sinh Viên'});
    await col(ForumService.categoriesCollection)
        .doc('c1')
        .set({'subject': 'Học bổng'});

    // Bài viết
    await col(ForumService.requestsCollection).doc('p1').set(post(
        subject: 'Tư vấn học bổng',
        userId: 'u1',
        time: DateTime(2026, 1, 1)));
    await col(ForumService.requestsCollection).doc('p2').set(post(
        subject: 'Đăng ký học phần',
        userId: 'u2',
        time: DateTime(2026, 1, 2)));
    await col(ForumService.requestsCollection).doc('p3').set(post(
        subject: 'Bài bị ẩn',
        userId: 'u2',
        time: DateTime(2026, 1, 3),
        hidden: true));
  });

  // ==================================================================
  // _uid (qua isAdmin / getUserInfo / getSuggestions)
  // ==================================================================
  group('_uid - yêu cầu đăng nhập', () {
    test('TC_UID_01: currentUserId trả về null -> ForumException', () async {
      currentUid = null;
      await expectLater(build().isAdmin(), throwsForum('Chưa đăng nhập!'));
    });

    test('TC_UID_02: currentUserId trả về chuỗi rỗng -> ForumException',
        () async {
      currentUid = '';
      await expectLater(build().isAdmin(), throwsForum('Chưa đăng nhập!'));
    });

    test('TC_UID_03: có uid hợp lệ -> không ném lỗi', () async {
      currentUid = 'u1';
      await expectLater(build().isAdmin(), completion(isFalse));
    });
  });

  // ==================================================================
  // isAdmin
  // ==================================================================
  group('isAdmin', () {
    test('TC_ADM_01: vai trò ROLE_ADMIN -> true', () async {
      currentUid = 'admin1';
      expect(await build().isAdmin(), isTrue);
    });

    test('TC_ADM_02: vai trò ROLE_STUDENT -> false', () async {
      currentUid = 'u1';
      expect(await build().isAdmin(), isFalse);
    });

    test('TC_ADM_03: vai trò viết thường "admin" vẫn là admin', () async {
      await col(ForumService.usersCollection)
          .doc('adm2')
          .set({'id': 'adm2', 'role': 'admin'});
      currentUid = 'adm2';
      expect(await build().isAdmin(), isTrue);
    });

    test('TC_ADM_04: người dùng không có trong Firestore -> false', () async {
      currentUid = 'khong_ton_tai';
      expect(await build().isAdmin(), isFalse);
    });

    test('TC_ADM_05: kết quả được cache (đổi vai trò sau đó không ảnh hưởng)',
        () async {
      currentUid = 'admin1';
      final svc = build();
      expect(await svc.isAdmin(), isTrue);

      await col(ForumService.usersCollection)
          .doc('admin1')
          .update({'role': 'ROLE_STUDENT'});
      expect(await svc.isAdmin(), isTrue); // vẫn dùng cache
    });
  });

  // ==================================================================
  // _validType + _toggle (qua votePost)
  // ==================================================================
  group('votePost (_validType, _toggle)', () {
    final types = kReactionTypes.toList();

    test('TC_VAL_01: loại reaction không hợp lệ -> ForumException', () async {
      await expectLater(
        build().votePost('p1', 'KHONG_HOP_LE'),
        throwsForum('Loại reaction không hợp lệ!'),
      );
    });

    test('TC_VAL_02: loại reaction viết thường được chuẩn hóa thành chữ hoa',
        () async {
      final r = await build().votePost('p1', types.first.toLowerCase());
      expect(r.currentType, types.first.toUpperCase());
    });

    test('TC_TOG_01: chưa có vote -> tạo mới', () async {
      final r = await build().votePost('p1', types.first);
      expect(r.currentType, types.first.toUpperCase());
      expect(await docExists(ForumService.votesCollection, 'u1_p1'), isTrue);
    });

    test('TC_TOG_02: vote cùng loại lần nữa -> bỏ vote (currentType = null)',
        () async {
      final svc = build();
      await svc.votePost('p1', types.first);
      final r = await svc.votePost('p1', types.first);
      expect(r.currentType, isNull);
      expect(await docExists(ForumService.votesCollection, 'u1_p1'), isFalse);
    });

    test('TC_TOG_03: vote khác loại -> đổi loại reaction', () async {
      final svc = build();
      await svc.votePost('p1', types[0]);
      final r = await svc.votePost('p1', types[1]);
      expect(r.currentType, types[1].toUpperCase());
      final data = await docData(ForumService.votesCollection, 'u1_p1');
      expect(data?['reactionType'], types[1].toUpperCase());
    });

    test('TC_TOG_04: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().votePost('p1', types.first),
        throwsForum('Chưa đăng nhập!'),
      );
    });

    test('TC_TOG_05: hai người dùng vote độc lập, mỗi người một document',
        () async {
      currentUid = 'u1';
      await build().votePost('p1', types.first);
      currentUid = 'u2';
      await build().votePost('p1', types.first);
      expect(await docExists(ForumService.votesCollection, 'u1_p1'), isTrue);
      expect(await docExists(ForumService.votesCollection, 'u2_p1'), isTrue);
    });
  });

  // ==================================================================
  // addComment
  // ==================================================================
  group('addComment', () {
    test('TC_ADD_01: nội dung rỗng -> ForumException', () async {
      await expectLater(
        build().addComment('p1', ''),
        throwsForum('Nội dung bình luận không được để trống'),
      );
    });

    test('TC_ADD_02: nội dung chỉ có khoảng trắng -> ForumException',
        () async {
      await expectLater(
        build().addComment('p1', '   \n  '),
        throwsForum('Nội dung bình luận không được để trống'),
      );
    });

    test('TC_ADD_03: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().addComment('p1', 'Xin chào'),
        throwsForum('Chưa đăng nhập!'),
      );
    });

    test('TC_ADD_04: bình luận gốc - cắt khoảng trắng, không có parent/reply',
        () async {
      final c = await build().addComment('p1', '  Cảm ơn bạn  ');
      expect(c.content, 'Cảm ơn bạn');
      expect(c.parentId, isNull);
      expect(c.replyId, isNull);
      expect(c.userId, 'u1');
      expect(c.userName, 'Nguyễn Văn A');
      expect(c.canDelete, isTrue);
      expect(await docExists(ForumService.commentsCollection, c.id), isTrue);
    });

    test('TC_ADD_05: trả lời bình luận gốc -> parentId = replyId = id gốc',
        () async {
      final svc = build();
      final root = await svc.addComment('p1', 'Gốc');
      final reply = await svc.addComment('p1', 'Trả lời', replyTo: root);
      expect(reply.parentId, root.id);
      expect(reply.replyId, root.id);
      expect(reply.replyToUserId, root.userId);
    });

    test(
        'TC_ADD_06: trả lời một reply -> parentId vẫn là gốc, replyId là reply',
        () async {
      final svc = build();
      final root = await svc.addComment('p1', 'Gốc');
      final r1 = await svc.addComment('p1', 'Reply 1', replyTo: root);
      final r2 = await svc.addComment('p1', 'Reply 2', replyTo: r1);
      expect(r2.parentId, root.id);
      expect(r2.replyId, r1.id);
    });

    test('TC_ADD_07: người dùng thiếu tên -> userName "Ẩn danh"', () async {
      currentUid = 'u4';
      final c = await build().addComment('p1', 'Test');
      expect(c.userName, 'Ẩn danh');
      expect(c.userRole, 'ROLE_STUDENT');
    });
  });

  // ==================================================================
  // deleteComment
  // ==================================================================
  group('deleteComment', () {
    setUp(() async {
      final c = col(ForumService.commentsCollection);
      await c.doc('c1').set({
        'userId': 'u1',
        'requestId': 'p1',
        'content': 'Gốc',
        'isActive': true,
      });
      await c.doc('c2').set({
        'userId': 'u2',
        'requestId': 'p1',
        'content': 'Reply 1',
        'parentId': 'c1',
        'isActive': true,
      });
      await c.doc('c3').set({
        'userId': 'u2',
        'requestId': 'p1',
        'content': 'Reply 2',
        'parentId': 'c1',
        'isActive': true,
      });
      await c.doc('c4').set({
        'userId': 'u1',
        'requestId': 'p1',
        'content': 'Bình luận khác',
        'isActive': true,
      });
    });

    test('TC_DEL_01: bình luận không tồn tại -> kết thúc, không ném lỗi',
        () async {
      await build().deleteComment('khong_co');
      expect(await docData(ForumService.commentsCollection, 'c1'),
          containsPair('isActive', true));
    });

    test('TC_DEL_02: không phải chủ bình luận -> ForumException', () async {
      currentUid = 'u2';
      await expectLater(
        build().deleteComment('c1'),
        throwsForum('Bạn không có quyền xóa bình luận này'),
      );
      expect(await docData(ForumService.commentsCollection, 'c1'),
          containsPair('isActive', true));
    });

    test('TC_DEL_03: chủ xóa bình luận gốc -> gốc và mọi reply bị ẩn mềm',
        () async {
      currentUid = 'u1';
      await build().deleteComment('c1');
      for (final id in ['c1', 'c2', 'c3']) {
        expect(await docData(ForumService.commentsCollection, id),
            containsPair('isActive', false),
            reason: 'comment $id phải có isActive = false');
      }
    });

    test('TC_DEL_04: xóa mềm không đụng tới bình luận không liên quan',
        () async {
      currentUid = 'u1';
      await build().deleteComment('c1');
      expect(await docData(ForumService.commentsCollection, 'c4'),
          containsPair('isActive', true));
    });

    test('TC_DEL_05: xóa mềm - document vẫn còn trong Firestore', () async {
      currentUid = 'u1';
      await build().deleteComment('c4');
      expect(await docExists(ForumService.commentsCollection, 'c4'), isTrue);
    });

    test('TC_DEL_06: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().deleteComment('c1'),
        throwsForum('Chưa đăng nhập!'),
      );
    });
  });

  // ==================================================================
  // reportPost
  // ==================================================================
  group('reportPost', () {
    test('TC_RPP_01: admin báo cáo -> ForumException', () async {
      currentUid = 'admin1';
      await expectLater(
        build().reportPost('p2', 'Spam'),
        throwsForum('Quản trị viên không thể báo cáo bài viết'),
      );
    });

    test('TC_RPP_02: lý do rỗng -> ForumException', () async {
      await expectLater(
        build().reportPost('p2', '   '),
        throwsForum('Vui lòng chọn lý do báo cáo'),
      );
    });

    test('TC_RPP_03: bài viết không tồn tại -> ForumException', () async {
      await expectLater(
        build().reportPost('khong_co', 'Spam'),
        throwsForum('Bài viết không còn tồn tại'),
      );
    });

    test('TC_RPP_04: báo cáo bài của chính mình -> ForumException', () async {
      currentUid = 'u1'; // p1 do u1 đăng
      await expectLater(
        build().reportPost('p1', 'Spam'),
        throwsForum('Bạn không thể báo cáo bài viết của chính mình'),
      );
    });

    test('TC_RPP_05: bài viết đã bị ẩn -> ForumException', () async {
      currentUid = 'u1'; // p3 do u2 đăng và đang bị ẩn
      await expectLater(
        build().reportPost('p3', 'Spam'),
        throwsForum('Bài viết này đã bị ẩn'),
      );
    });

    test('TC_RPP_06: báo cáo hợp lệ -> tạo báo cáo pending + thông báo admin',
        () async {
      currentUid = 'u1';
      await build().reportPost('p2', '  Nội dung sai sự thật  ');

      final report =
          await docData(ForumService.postReportsCollection, 'u1_p2');
      expect(report, isNotNull);
      expect(report!['status'], 'pending');
      expect(report['reason'], 'Nội dung sai sự thật');
      expect(report['requestId'], 'p2');
      expect(report['studentId'], 'u1');

      final noti = await docData(
          ForumService.adminNotificationsCollection, 'POST_REPORT_u1_p2');
      expect(noti, isNotNull);
      expect(noti!['type'], 'POST_REPORT');
      expect(noti['isRead'], false);
    });

    test('TC_RPP_07: báo cáo lần hai cùng bài -> ForumException', () async {
      currentUid = 'u1';
      final svc = build();
      await svc.reportPost('p2', 'Spam');
      await expectLater(
        svc.reportPost('p2', 'Spam'),
        throwsForum('Bạn đã báo cáo bài viết này rồi'),
      );
    });

    test('TC_RPP_08: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().reportPost('p2', 'Spam'),
        throwsForum('Chưa đăng nhập!'),
      );
    });
  });

  // ==================================================================
  // setPostHidden
  // ==================================================================
  group('setPostHidden', () {
    setUp(() async {
      final r = col(ForumService.postReportsCollection);
      await r.doc('r1').set({'requestId': 'p2', 'status': 'pending'});
      await r.doc('r2').set({'requestId': 'p2', 'status': 'violation'});
      await r.doc('r3').set({'requestId': 'p2', 'status': 'not_violation'});
      await r.doc('r4').set({'requestId': 'p1', 'status': 'pending'});
    });

    Future<String?> statusOf(String id) async =>
        (await docData(ForumService.postReportsCollection, id))?['status']
            as String?;

    test('TC_HID_01: người dùng thường -> ForumException', () async {
      currentUid = 'u1';
      await expectLater(
        build().setPostHidden('p2', hidden: true),
        throwsForum('Chỉ quản trị viên mới được ẩn/hiện bài viết'),
      );
    });

    test('TC_HID_02: admin, bài viết không tồn tại -> ForumException',
        () async {
      currentUid = 'admin1';
      await expectLater(
        build().setPostHidden('khong_co', hidden: true),
        throwsForum('Bài viết không còn tồn tại'),
      );
    });

    test('TC_HID_03: ẩn bài -> isHidden = true', () async {
      currentUid = 'admin1';
      await build().setPostHidden('p2', hidden: true);
      expect(await docData(ForumService.requestsCollection, 'p2'),
          containsPair('isHidden', true));
    });

    test('TC_HID_04: ẩn bài -> báo cáo pending thành violation, còn lại giữ',
        () async {
      currentUid = 'admin1';
      await build().setPostHidden('p2', hidden: true);
      expect(await statusOf('r1'), 'violation'); // pending -> violation
      expect(await statusOf('r2'), 'violation'); // giữ nguyên
      expect(await statusOf('r3'), 'not_violation'); // giữ nguyên
    });

    test('TC_HID_05: hiện lại -> violation thành not_violation, pending giữ',
        () async {
      currentUid = 'admin1';
      await build().setPostHidden('p2', hidden: false);
      expect(await docData(ForumService.requestsCollection, 'p2'),
          containsPair('isHidden', false));
      expect(await statusOf('r1'), 'pending'); // giữ nguyên
      expect(await statusOf('r2'), 'not_violation'); // violation -> not_violation
      expect(await statusOf('r3'), 'not_violation'); // giữ nguyên
    });

    test('TC_HID_06: ẩn bài không ảnh hưởng báo cáo của bài khác', () async {
      currentUid = 'admin1';
      await build().setPostHidden('p2', hidden: true);
      expect(await statusOf('r4'), 'pending');
    });
  });

  // ==================================================================
  // getUserInfo
  // ==================================================================
  group('getUserInfo', () {
    test('TC_USR_01: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().getUserInfo('u1'),
        throwsForum('Chưa đăng nhập!'),
      );
    });

    test('TC_USR_02: userId rỗng / chỉ khoảng trắng -> null', () async {
      expect(await build().getUserInfo(''), isNull);
      expect(await build().getUserInfo('   '), isNull);
    });

    test('TC_USR_03: người dùng không tồn tại -> null', () async {
      expect(await build().getUserInfo('khong_co'), isNull);
    });

    test('TC_USR_04: người dùng có phòng ban -> trả đủ thông tin', () async {
      final u = await build().getUserInfo('u1');
      expect(u, isNotNull);
      expect(u!.id, 'u1');
      expect(u.fullName, 'Nguyễn Văn A');
      expect(u.email, 'a@student.ute.edu.vn');
      expect(u.role, 'ROLE_STUDENT');
      expect(u.departmentId, 'd1');
      expect(u.departmentName, 'Phòng Đào Tạo');
    });

    test('TC_USR_05: người dùng không có phòng ban -> departmentName = null',
        () async {
      final u = await build().getUserInfo('u2');
      expect(u, isNotNull);
      expect(u!.departmentId, isNull);
      expect(u.departmentName, isNull);
    });

    test('TC_USR_06: thiếu tên và vai trò -> "Ẩn danh" và ROLE_STUDENT',
        () async {
      final u = await build().getUserInfo('u4');
      expect(u, isNotNull);
      expect(u!.fullName, 'Ẩn danh');
      expect(u.role, 'ROLE_STUDENT');
    });
  });

  // ==================================================================
  // getSuggestions
  // ==================================================================
  group('getSuggestions', () {
    List<String> postTexts(List<SearchSuggestion> list) => list
        .where((s) => s.type == SuggestionType.post)
        .map((s) => s.text)
        .toList();

    test('TC_SUG_01: chưa đăng nhập -> ForumException', () async {
      currentUid = null;
      await expectLater(
        build().getSuggestions('hoc'),
        throwsForum('Chưa đăng nhập!'),
      );
    });

    test('TC_SUG_02: từ khóa rỗng / chỉ khoảng trắng -> danh sách rỗng',
        () async {
      expect(await build().getSuggestions(''), isEmpty);
      expect(await build().getSuggestions('   '), isEmpty);
    });

    test('TC_SUG_03: tìm không dấu vẫn khớp tiêu đề có dấu', () async {
      final r = await build().getSuggestions('tu van');
      expect(postTexts(r), contains('Tư vấn học bổng'));
    });

    test('TC_SUG_04: mọi chữ trong từ khóa đều phải khớp', () async {
      final r = await build().getSuggestions('tu phan');
      expect(postTexts(r), isEmpty); // không tiêu đề nào chứa cả "tu" và "phan"
    });

    test(
        'TC_SUG_05: tiêu đề bắt đầu bằng chữ đầu được ưu tiên, còn lại mới -> cũ',
        () async {
      await col(ForumService.requestsCollection).doc('pA').set(post(
          subject: 'Thông tin học bổng',
          userId: 'u2',
          time: DateTime(2026, 1, 5)));
      await col(ForumService.requestsCollection).doc('pB').set(post(
          subject: 'Học bổng toàn phần',
          userId: 'u2',
          time: DateTime(2026, 1, 4)));

      final r = await build().getSuggestions('hoc bong');
      expect(postTexts(r), [
        'Học bổng toàn phần', // bắt đầu bằng "hoc" -> lên đầu dù cũ hơn
        'Thông tin học bổng', // mới hơn
        'Tư vấn học bổng', // cũ nhất
      ]);
    });

    test('TC_SUG_06: giới hạn số gợi ý bài viết theo tham số limit', () async {
      await col(ForumService.requestsCollection).doc('pA').set(post(
          subject: 'Thông tin học bổng',
          userId: 'u2',
          time: DateTime(2026, 1, 5)));
      final r = await build().getSuggestions('hoc bong', limit: 1);
      expect(postTexts(r).length, 1);
    });

    test('TC_SUG_07: gợi ý phòng ban khớp tên (không phân biệt dấu)',
        () async {
      final r = await build().getSuggestions('dao tao');
      final deps =
          r.where((s) => s.type == SuggestionType.department).toList();
      expect(deps.length, 1);
      expect(deps.first.text, 'Phòng Đào Tạo');
      expect(deps.first.departmentId, 'd1');
    });

    test('TC_SUG_08: người thường không thấy tiêu đề bài bị ẩn', () async {
      currentUid = 'u1';
      final r = await build().getSuggestions('bai bi an');
      expect(postTexts(r), isEmpty);
    });

    test('TC_SUG_09: admin thấy cả tiêu đề bài bị ẩn', () async {
      currentUid = 'admin1';
      final r = await build().getSuggestions('bai bi an');
      expect(postTexts(r), contains('Bài bị ẩn'));
    });

    test('TC_SUG_10: tiêu đề trùng (sau khi bỏ dấu) chỉ xuất hiện một lần',
        () async {
      await col(ForumService.requestsCollection).doc('pDup').set(post(
          subject: 'TU VAN HOC BONG',
          userId: 'u2',
          time: DateTime(2026, 1, 6)));
      final r = await build().getSuggestions('tu van');
      expect(postTexts(r).length, 1);
    });
  });
}