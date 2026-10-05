import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:app_gdtm/models/enums/user_role.dart';
import 'package:app_gdtm/models/Notification.dart' as app_notification;
import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';

import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/app_menu.dart';
import 'package:app_gdtm/widgets/app_shell.dart';
import 'package:app_gdtm/widgets/chatbot_panel.dart';
import 'package:app_gdtm/widgets/post_link.dart';

import 'package:app_gdtm/pages/common/notification_page.dart';
import 'package:app_gdtm/pages/common/change_password_page.dart';
import 'package:app_gdtm/pages/login/login_page.dart';

import 'package:app_gdtm/services/AuthService.dart';
import 'package:app_gdtm/services/chatbot_service.dart';
import 'package:app_gdtm/services/forum_service.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/services/comment_report_service.dart';
import 'package:app_gdtm/services/post_report_service.dart';

import 'package:app_gdtm/pages/student/send_feedback_page.dart';
import 'package:app_gdtm/pages/student/edit_feedback_page.dart';
import 'package:app_gdtm/pages/student/feedback_history_page.dart';
import 'package:app_gdtm/pages/student/feedback_detail_page.dart';
import 'package:app_gdtm/pages/student/forum_page.dart';
import 'package:app_gdtm/pages/student/post_detail_page.dart';
import 'package:app_gdtm/pages/student/department_announcements_page.dart';

import 'package:app_gdtm/pages/staff/manage_notifications_page.dart';
import 'package:app_gdtm/pages/staff/staff_dashboard_page.dart';
import 'package:app_gdtm/pages/staff/staff_list_page.dart';

import 'package:app_gdtm/pages/admin/category_management_page.dart';
import 'package:app_gdtm/pages/admin/violation_comments_page.dart';
import 'package:app_gdtm/pages/admin/violation_posts_page.dart';

/// Trang chủ dashboard dùng chung cho Student / Staff / Admin.
class DashboardPage extends StatefulWidget {
  final UserRole role;
  final Users user;

  const DashboardPage({
    super.key,
    required this.role,
    required this.user,
  });

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedId = 'forum';

  Request? _selectedFeedback;

  List<Department> _feedbackDepartments = [];

  List<Category> _feedbackCategories = [];

  app_notification.Notification? _initialNotification;

  final ValueNotifier<app_notification.Notification?>
      _notificationReadNotifier =
      ValueNotifier(null);

  String _feedbackBackId = 'feedback_history';

  // ============================================================
  // SERVICES
  // ============================================================

  late final ForumService _forum = ForumService(
    currentUserId: () => widget.user.id,
  );

  late final AnnouncementService _announcements =
      AnnouncementService(
    currentUserId: () => widget.user.id,
  );

  late final ChatbotService _chatbot =
      _createChatbot();

  final CategoryService _categoryService =
      CategoryService();

  late final CommentReportService _reportService =
      CommentReportService(
    currentUserId: () => widget.user.id,
  );

  late final PostReportService _postReportService =
      PostReportService(
    currentUserId: () => widget.user.id,
  );

  // ============================================================
  // CHATBOT
  // ============================================================

  ChatbotService _createChatbot() {
    final ready = dotenv.isInitialized;

    final key = ready
        ? (dotenv.maybeGet('GEMINI_API_KEY') ?? '')
        : '';

    final model = ready
        ? (dotenv.maybeGet('GEMINI_MODEL') ?? '').trim()
        : '';

    final fallback = ready
        ? (dotenv.maybeGet(
              'GEMINI_FALLBACK_MODEL',
            ) ??
            '').trim()
        : '';

    return ChatbotService(
      announcements: _announcements,
      apiKey: key,
      model: model.isEmpty
          ? ChatbotService.defaultModel
          : model,
      fallbackModel:
          fallback.isEmpty ? null : fallback,
    );
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    PostLink.openHandler = _openPostById;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        final id =
            PostLink.consumeInitialPostId();

        if (id != null && mounted) {
          _openPostById(id);
        }
      },
    );
  }

  // ============================================================
  // OPEN POST
  // ============================================================

  Future<void> _openPostById(
    String postId,
  ) async {
    final messenger =
        ScaffoldMessenger.of(context);

    try {
      final post =
          await fetchPublicPost(
        _forum,
        postId,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(
            initialPost: post,
            service: _forum,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static const AppMenuItem _logoutItem =
      AppMenuItem(
    id: 'logout',
    title: 'Đăng xuất',
    icon: Icons.logout,
  );

  // ============================================================
  // MENU
  // ============================================================

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
                id: 'department_announcements',
                title: 'Thông báo phòng ban',
                icon: Icons.campaign,
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
                id: 'violation_posts',
                title: 'Quản lý bài viết vi phạm',
                icon: Icons.flag,
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

  // ============================================================
  // COMMON PAGES
  // ============================================================

  Widget _forumPage({
    VoidCallback? onCompose,
  }) {
    return ForumPage(
      service: _forum,
      embedded: true,
      currentUserName:
          widget.user.fullName ?? '',
      onCompose: onCompose,
      canReport:
          widget.role != UserRole.admin,
    );
  }

  Widget _changePasswordPage() {
    return ChangePasswordPage(
      user: widget.user,
      onSuccess: () {
        setState(() {
          _selectedId = 'forum';
        });
      },
    );
  }

  // ============================================================
  // BUILD CONTENT
  // ============================================================

  Widget _buildContent() {
    switch (widget.role) {
      // ========================================================
      // STUDENT
      // ========================================================

      case UserRole.student:
        switch (_selectedId) {
          case 'feedback_history':
            return FeedbackHistoryPage(
              user: widget.user,
              onEditRequest:
                  _openEditFeedback,
              onOpenDetail:
                  (
                    request,
                    departments,
                    categories,
                  ) {
                setState(() {
                  _selectedFeedback =
                      request;

                  _feedbackDepartments =
                      departments;

                  _feedbackCategories =
                      categories;

                  _feedbackBackId =
                      'feedback_history';

                  _selectedId =
                      'feedback_detail';
                });
              },
            );

          case 'feedback_detail':
            final request =
                _selectedFeedback;

            if (request == null) {
              return FeedbackHistoryPage(
                user: widget.user,
              );
            }

            return FeedbackDetailPage(
              request: request,
              user: widget.user,
              departments:
                  _feedbackDepartments,
              categories:
                  _feedbackCategories,
              onBack: () {
                setState(() {
                  _selectedId =
                      _feedbackBackId;
                });
              },
            );

          case 'feedback_edit':
            final request =
                _selectedFeedback;

            if (request == null) {
              return FeedbackHistoryPage(
                user: widget.user,
                onEditRequest:
                    _openEditFeedback,
              );
            }

            return EditFeedbackPage(
              user: widget.user,
              request: request,
              onSaved:
                  _finishEditFeedback,
              onCancel:
                  _closeEditFeedback,
            );

          case 'notifications':
            return NotificationPage(
              user: widget.user,
              initialNotification:
                  _initialNotification,
              onOpenFeedback:
                  _openFeedbackFromNotification,
              onReadChanged:
                  _onNotificationReadChanged,
            );

          case 'department_announcements':
            return DepartmentAnnouncementsPage(
              service: _announcements,
            );

          case 'send_feedback':
            return SendFeedbackPage(
              user: widget.user,
              onSubmitted: () {
                setState(() {
                  _selectedId =
                      'feedback_history';
                });
              },
            );

          case 'forum':
            return _forumPage(
              onCompose: () {
                setState(() {
                  _selectedId =
                      'send_feedback';
                });
              },
            );

          case 'change_password':
            return _changePasswordPage();

          default:
            return _PlaceholderPage(
              title: _titleOf(
                _selectedId,
              ),
            );
        }

      // ========================================================
      // STAFF
      // ========================================================

      case UserRole.staff:
        switch (_selectedId) {
          case 'feedback_inbox':
            return StaffListPage(
              role: 'ROLE_TEACHER',
              departmentId:
                  widget.user.departmentId,
              staffUserId:
                  widget.user.id!,
            );

          case 'statistics':
            return StaffDashboardPage(
              role: 'ROLE_TEACHER',
              departmentId:
                  widget.user.departmentId,
              staffUserId:
                  widget.user.id!,
            );

          case 'manage_notifications':
            return ManageNotificationsPage(
              service: _announcements,
            );

          case 'notifications':
            return NotificationPage(
              user: widget.user,
              initialNotification:
                  _initialNotification,
              onOpenFeedback:
                  _openFeedbackFromNotification,
              onReadChanged:
                  _onNotificationReadChanged,
            );

          case 'forum':
            return _forumPage();

          case 'change_password':
            return _changePasswordPage();

          default:
            return _PlaceholderPage(
              title: _titleOf(
                _selectedId,
              ),
            );
        }

      // ========================================================
      // ADMIN
      // ========================================================

      case UserRole.admin:
        switch (_selectedId) {
          case 'feedback_inbox':
            return StaffListPage(
              role: 'ROLE_ADMIN',

              // Admin xem được tất cả request.
              departmentId:
                  widget.user.departmentId,

              // QUAN TRỌNG:
              // ID admin đang đăng nhập
              // dùng cho update status.
              staffUserId:
                  widget.user.id!,
            );

          case 'notifications':
            return NotificationPage(
              user: widget.user,
              initialNotification:
                  _initialNotification,
              onOpenFeedback:
                  _openFeedbackFromNotification,
              onReadChanged:
                  _onNotificationReadChanged,
            );

          case 'forum':
            return _forumPage();

          case 'manage_categories':
            return CategoryManagementPage(
              service: _categoryService,
              embedded: true,
            );

          case 'violation_posts':
            return ViolationPostsPage(
              service:
                  _postReportService,
              forum: _forum,
              embedded: true,
            );

          case 'violation_comments':
            return ViolationCommentsPage(
              service: _reportService,
              forum: _forum,
              embedded: true,
            );

          case 'change_password':
            return _changePasswordPage();

          default:
            return _PlaceholderPage(
              title: _titleOf(
                _selectedId,
              ),
            );
        }
    }
  }

  // ============================================================
  // TITLE
  // ============================================================

  String _titleOf(String id) {
    for (final section
        in _menuSections) {
      for (final item
          in section.items) {
        if (item.id == id) {
          return item.title;
        }
      }
    }

    return '';
  }

  // ============================================================
  // MENU
  // ============================================================

  void _onMenuSelected(String id) {
    if (id == 'logout') {
      AuthService().signOut();

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const LoginPage(),
        ),
        (route) => false,
      );

      return;
    }

    setState(() {
      _selectedId = id;

      if (id != 'notifications') {
        _initialNotification = null;
      }
    });
  }

  // ============================================================
  // NOTIFICATION
  // ============================================================

  void _onNotificationSelected(
    app_notification.Notification
        notification,
  ) {
    setState(() {
      _initialNotification =
          notification;

      _selectedId =
          'notifications';
    });
  }

  void _openFeedbackFromNotification(
    Request request,
  ) {
    setState(() {
      _selectedFeedback =
          request;

      _feedbackDepartments = [];

      _feedbackCategories = [];

      _feedbackBackId =
          'notifications';

      _initialNotification =
          null;

      _selectedId =
          'feedback_detail';
    });
  }

  void _onNotificationReadChanged(
    app_notification.Notification
        notification,
  ) {
    _notificationReadNotifier
        .value = notification.copyWith();
  }

  // ============================================================
  // STUDENT FEEDBACK
  // ============================================================

  void _openEditFeedback(
    Request request,
  ) {
    setState(() {
      _selectedFeedback =
          request;

      _feedbackBackId =
          'feedback_history';

      _selectedId =
          'feedback_edit';
    });
  }

  void _finishEditFeedback() {
    setState(() {
      _selectedId =
          'feedback_history';
    });
  }

  void _closeEditFeedback() {
    setState(() {
      _selectedId =
          _feedbackBackId;
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    PostLink.openHandler = null;

    _notificationReadNotifier
        .dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AppShell(
      sections: _menuSections,

      footerItems: const [
        _logoutItem,
      ],

      selectedMenuId:
          _selectedId,

      onMenuSelected:
          _onMenuSelected,

      onNotificationSelected:
          _onNotificationSelected,

      notificationReadNotifier:
          _notificationReadNotifier,

      user: widget.user,

      child: Stack(
        children: [
          Positioned.fill(
            child: _buildContent(),
          ),

          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag:
                  'chatbot_fab',
              tooltip:
                  'Hỏi trợ lý thông báo',
              backgroundColor:
                  AppColors.primary,
              foregroundColor:
                  Colors.white,
              onPressed: () =>
                  showChatbotSheet(
                context,
                _chatbot,
              ),
              child: const Icon(
                Icons
                    .smart_toy_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PLACEHOLDER
// ============================================================================

class _PlaceholderPage
    extends StatelessWidget {
  final String title;

  const _PlaceholderPage({
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight:
              FontWeight.bold,
          color:
              AppColors.primary,
        ),
      ),
    );
  }
}