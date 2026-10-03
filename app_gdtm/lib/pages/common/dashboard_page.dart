import 'package:flutter/material.dart';

import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/app_menu.dart';
import 'package:app_gdtm/widgets/app_shell.dart';
import 'package:app_gdtm/pages/common/notification_page.dart';
import 'package:app_gdtm/pages/login/login_page.dart';
import 'package:app_gdtm/services/AuthService.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/pages/student/send_feedback_page.dart';
import 'package:app_gdtm/pages/student/feedback_history_page.dart';
import 'package:app_gdtm/pages/student/feedback_detail_page.dart';
import 'package:app_gdtm/pages/student/forum_page.dart';
import 'package:app_gdtm/pages/staff/manage_notifications_page.dart';
import 'package:app_gdtm/pages/common/change_password_page.dart';
import 'package:app_gdtm/pages/admin/category_management_page.dart';
import 'package:app_gdtm/services/comment_report_service.dart';
import 'package:app_gdtm/pages/admin/violation_comments_page.dart';

/// Trang chủ dashboard: khung (header + menu) dùng chung,
/// menu và nội dung đổi theo role và mục menu được chọn.
class DashboardPage extends StatefulWidget {
  /// Role của tài khoản vừa đăng nhập.
  final UserRole role;

  /// Thông tin người dùng vừa đăng nhập.
  final Users user;

  const DashboardPage({
    super.key,
    required this.role,
    required this.user,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Role lấy từ tài khoản đăng nhập (widget.role)
  // final String _userId = '23110147'; // TODO: lấy từ user đăng nhập

  String _selectedId = 'notifications';
  Request? _selectedFeedback;
  List<Department> _feedbackDepartments = [];
  List<Category> _feedbackCategories = [];

  /// Service diễn đàn (dùng chung cho mọi role). Users.id là userId lưu trên Firestore.
  late final ForumService _forum = ForumService(
    currentUserId: () => widget.user.id,
  );

  /// Service thông báo (xem: mọi role; đăng: giảng viên).
  late final AnnouncementService _announcements = AnnouncementService(
    currentUserId: () => widget.user.id,
  );

  /// Service danh mục (dùng cho trang quản lý danh mục của admin).
  final CategoryService _categoryService = CategoryService();

  /// Service kiểm duyệt báo cáo bình luận (admin).
  late final CommentReportService _reportService = CommentReportService(
    currentUserId: () => widget.user.id,
  );

  /// Mục "Đăng xuất" ghim ở đáy menu, dùng chung mọi role.
  static const AppMenuItem _logoutItem = AppMenuItem(
    id: 'logout',
    title: 'Đăng xuất',
    icon: Icons.logout,
  );

  /// Menu theo role
  List<AppMenuSection> get _menuSections {
    switch (widget.role) {
      case UserRole.student:
        return const [
          AppMenuSection(
            title: '',
            items: [
              AppMenuItem(
                id: 'feedback_history',
                title: 'Lịch sử góp ý',
                icon: Icons.history,
              ),
              AppMenuItem(
                id: 'send_feedback',
                title: 'Gửi góp ý',
                icon: Icons.edit,
              ),
              AppMenuItem(
                id: 'forum',
                title: 'Diễn đàn',
                icon: Icons.forum,
              ),
              AppMenuItem(
                id: 'notifications',
                title: 'Thông báo',
                icon: Icons.notifications,
              ),
              AppMenuItem(
                id: 'change_password',
                title: 'Đổi mật khẩu',
                icon: Icons.key,
              ),
            ],
          ),
        ];

      case UserRole.staff:
        return const [
          AppMenuSection(
            title: '',
            items: [
              AppMenuItem(
                id: 'feedback_inbox',
                title: 'Góp ý tiếp nhận',
                icon: Icons.inbox,
              ),
              AppMenuItem(
                id: 'forum',
                title: 'Diễn đàn',
                icon: Icons.forum,
              ),
              AppMenuItem(
                id: 'manage_notifications',
                title: 'Quản lý thông báo',
                icon: Icons.checklist,
              ),
              AppMenuItem(
                id: 'notifications',
                title: 'Thông báo',
                icon: Icons.notifications,
              ),
              AppMenuItem(
                id: 'statistics',
                title: 'Thống kê',
                icon: Icons.show_chart,
              ),
              AppMenuItem(
                id: 'change_password',
                title: 'Đổi mật khẩu',
                icon: Icons.manage_accounts,
              ),
            ],
          ),
        ];

      case UserRole.admin:
        return const [
          AppMenuSection(
            title: '',
            items: [
              AppMenuItem(
                id: 'feedback_inbox',
                title: 'Góp ý tiếp nhận',
                icon: Icons.edit,
              ),
              AppMenuItem(
                id: 'violation_comments',
                title: 'Quản lý bình luận vi phạm',
                icon: Icons.block,
              ),
              AppMenuItem(
                id: 'manage_categories',
                title: 'Quản lý danh mục',
                icon: Icons.list,
              ),
              AppMenuItem(
                id: 'forum',
                title: 'Diễn đàn',
                icon: Icons.chat_bubble,
              ),
              AppMenuItem(
                id: 'notifications',
                title: 'Thông báo',
                icon: Icons.notifications,
              ),
              AppMenuItem(
                id: 'change_password',
                title: 'Đổi mật khẩu',
                icon: Icons.key,
              ),
            ],
          ),
        ];
    }
  }

  /// Trang diễn đàn dùng chung. [onCompose] chỉ có ở sinh viên (nơi gửi được góp ý).
  Widget _forumPage({VoidCallback? onCompose}) {
    return ForumPage(
      service: _forum,
      embedded: true, // AppShell đã có header, không vẽ AppBar riêng
      currentUserName: widget.user.fullName ?? '',
      onCompose: onCompose,
      canReport: widget.role != UserRole.admin, // admin không báo cáo bình luận
    );
  }

  /// Trang thông báo dùng chung cho mọi role (tab "Thông báo chung" xem thông báo giảng viên đăng).
  Widget _notificationPage() => NotificationPage(service: _announcements);

  /// Trang đổi mật khẩu dùng chung cho mọi role.
  /// Đổi xong quay về trang chủ (mục "Thông báo" - mục mở sẵn sau khi đăng nhập).
  Widget _changePasswordPage() {
    return ChangePasswordPage(
      user: widget.user,
      onSuccess: () => setState(() => _selectedId = 'notifications'),
    );
  }

  /// Nội dung theo role + menu đang chọn.
  /// Thêm trang mới: thêm một `case` với id của menu ở đúng role.
  Widget _buildContent() {
    switch (widget.role) {
      case UserRole.student:
        switch (_selectedId) {
          case 'feedback_history':
            return FeedbackHistoryPage(
              user: widget.user,
              onOpenDetail: (request, departments, categories) {
                setState(() {
                  _selectedFeedback = request;
                  _feedbackDepartments = departments;
                  _feedbackCategories = categories;
                  _selectedId = 'feedback_detail';
                });
              },
            );
          case 'feedback_detail':
            final request = _selectedFeedback;
            if (request == null) {
              return FeedbackHistoryPage(user: widget.user);
            }
            return FeedbackDetailPage(
              request: request,
              user: widget.user,
              departments: _feedbackDepartments,
              categories: _feedbackCategories,
              onBack: () => setState(
                () => _selectedId = 'feedback_history',
              ),
            );
          case 'notifications':
            return _notificationPage();
          case 'send_feedback':
            return SendFeedbackPage(
              user: widget.user,
              // Gửi xong thì chuyển sang "Lịch sử góp ý" (khi trang đó làm xong)
              onSubmitted: () => setState(() => _selectedId = 'feedback_history'),
            );
          case 'forum':
            return _forumPage(
              onCompose: () => setState(() => _selectedId = 'send_feedback'),
            );

          case 'change_password':
            return _changePasswordPage();

          default:
            return _PlaceholderPage(title: _titleOf(_selectedId));
        }

      case UserRole.staff:
        switch (_selectedId) {
          case 'notifications':
            return _notificationPage();
          case 'manage_notifications':
            return ManageNotificationsPage(service: _announcements);
          case 'forum':
            return _forumPage();

          case 'change_password':
            return _changePasswordPage();

          // TODO: case 'statistics': return const StatisticsPage();
          default:
            return _PlaceholderPage(title: _titleOf(_selectedId));
        }

      case UserRole.admin:
        switch (_selectedId) {
          case 'notifications':
            return _notificationPage();
          case 'forum':
            return _forumPage();
          // TODO: case 'manage_categories': return const CategoriesPage();

          case 'change_password':
            return _changePasswordPage();

          case 'violation_comments':
            return ViolationCommentsPage(
              service: _reportService,
              forum: _forum,
              embedded: true,
            );

          case 'manage_categories':
            return CategoryManagementPage(
              service: _categoryService,
              embedded: true, // AppShell đã có header, không vẽ AppBar riêng
            );
          default:
            return _PlaceholderPage(title: _titleOf(_selectedId));
        }
    }
  }

  String _titleOf(String id) {
    for (final s in _menuSections) {
      for (final i in s.items) {
        if (i.id == id) return i.title;
      }
    }
    return '';
  }

  void _onMenuSelected(String id) {
    if (id == 'logout') {
      // Quay về trang đăng nhập và xoá toàn bộ lịch sử điều hướng.
      // TODO: nếu sau này lưu phiên đăng nhập (token/SharedPreferences) thì xoá ở đây.
      AuthService().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sections: _menuSections,

      footerItems: const [
        _logoutItem,
      ],

      selectedMenuId: _selectedId,

      onMenuSelected: _onMenuSelected,

      // Người dùng đang đăng nhập
      user: widget.user,

      child: _buildContent(),
    );
  }
}

/// Trang tạm cho các menu chưa làm.
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}