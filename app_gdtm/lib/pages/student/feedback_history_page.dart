import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/pages/student/feedback_detail_page.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/services/DepartmentService.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/widgets/page_title.dart';

class FeedbackHistoryPage extends StatefulWidget {
  final Users user;
  final void Function(
    Request request,
    List<Department> departments,
    List<Category> categories,
  )? onOpenDetail;

  const FeedbackHistoryPage({
    super.key,
    required this.user,
    this.onOpenDetail,
  });

  @override
  State<FeedbackHistoryPage> createState() =>
      _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState
    extends State<FeedbackHistoryPage> {
  final _requestService = RequestService();
  final _searchController = TextEditingController();

  List<Request> _requests = [];
  List<Department> _departments = [];
  List<Category> _categories = [];

  bool _loading = true;
  String? _error;

  String _status = '';
  String _departmentId = '';
  String _categoryId = '';

  // ============================================================
  // HCMUTE COLOR
  // ============================================================

  static const Color hcmuteBlue =
      Color(0xFF005BAA);

  static const Color hcmuteLightBlue =
      Color(0xFFEAF4FC);

  static const Color background =
      Color(0xFFF4F7FB);

  static const Color textPrimary =
      Color(0xFF172B4D);

  static const Color textSecondary =
      Color(0xFF667085);

  static const Color borderColor =
      Color(0xFFE2E8F0);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadHistory();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _requestService.getStudentFeedbackHistory(
          widget.user.id ?? '',
        ),
        DepartmentService().getDepartments(),
        CategoryService().getActiveCategories(),
      ]);

      if (!mounted) return;

      setState(() {
        _requests = results[0] as List<Request>;
        _departments = results[1] as List<Department>;
        _categories = results[2] as List<Category>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Không tải được lịch sử góp ý: $e';
      });
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Request> get _filteredRequests {
    final keyword =
        _searchController.text.trim().toLowerCase();

    return _requests.where((request) {
      final matchesKeyword =
          keyword.isEmpty ||
          (request.subject ?? '')
              .toLowerCase()
              .contains(keyword) ||
          (request.description ?? '')
              .toLowerCase()
              .contains(keyword);

      final matchesStatus =
          _status.isEmpty ||
          request.currentStatus == _status;

      final matchesDepartment =
          _departmentId.isEmpty ||
          request.departmentId == _departmentId;

      final matchesCategory =
          _categoryId.isEmpty ||
          request.categoryIds.contains(_categoryId);

      return matchesKeyword &&
          matchesStatus &&
          matchesDepartment &&
          matchesCategory;
    }).toList();
  }

  // ============================================================
  // DEPARTMENT
  // ============================================================

  String _departmentName(String? id) =>
      _departments
          .where(
            (department) =>
                department.id == id,
          )
          .map(
            (department) =>
                department.name ?? '',
          )
          .firstOrNull ??
      'Chưa xác định phòng ban';

  // ============================================================
  // STATUS
  // ============================================================

  String _statusLabel(String? status) {
    switch (status) {
      case 'PENDING':
        return 'Đang chờ tiếp nhận';

      case 'FORWARDING':
        return 'Đã được chuyển tiếp';

      case 'APPROVED':
        return 'Đang xử lý';

      case 'RESOLVED':
        return 'Đã xử lý';

      case 'REJECTED':
        return 'Từ chối';

      default:
        return status ?? 'Chưa cập nhật';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'RESOLVED':
        return const Color(0xFF16A34A);

      case 'REJECTED':
        return const Color(0xFFDC2626);

      case 'APPROVED':
        return hcmuteBlue;

      case 'FORWARDING':
        return const Color(0xFFF59E0B);

      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'RESOLVED':
        return Icons.check_circle_outline;

      case 'REJECTED':
        return Icons.cancel_outlined;

      case 'APPROVED':
        return Icons.autorenew_rounded;

      case 'FORWARDING':
        return Icons.forward_outlined;

      default:
        return Icons.schedule_outlined;
    }
  }

  // ============================================================
  // AVAILABLE FILTERS
  // ============================================================

  Map<String, String> get _availableStatuses {
    const labels = {
      'PENDING': 'Đang chờ tiếp nhận',
      'FORWARDING': 'Đã được chuyển tiếp',
      'APPROVED': 'Đang xử lý',
      'RESOLVED': 'Đã xử lý',
      'REJECTED': 'Từ chối',
    };

    final values = _requests
        .map((request) => request.currentStatus)
        .whereType<String>()
        .toSet();

    return {
      for (final entry in labels.entries)
        if (values.contains(entry.key))
          entry.key: entry.value,
    };
  }

  Map<String, String> get _availableDepartments {
    final ids = _requests
        .map((request) => request.departmentId)
        .whereType<String>()
        .toSet();

    return {
      for (final department in _departments)
        if (department.id != null &&
            ids.contains(department.id))
          department.id!:
              department.name ?? 'Phòng ban',
    };
  }

  Map<String, String> get _availableCategories {
    final ids = _requests
        .expand(
          (request) => request.categoryIds,
        )
        .toSet();

    return {
      for (final category in _categories)
        if (category.id != null &&
            ids.contains(category.id))
          category.id!:
              category.subject,
    };
  }

  // ============================================================
  // DATE
  // ============================================================

  String _date(DateTime? value) {
    if (value == null) return '';

    final local = value.toLocal();

    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop =
              constraints.maxWidth >= 900;

          final double padding = desktop
              ? 48
              : constraints.maxWidth >= 600
                  ? 28
                  : 16;

          return RefreshIndicator(
            color: hcmuteBlue,
            onRefresh: _loadHistory,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                padding,
                18,
                padding,
                40,
              ),
              children: [
                _buildHeader(),

                const SizedBox(height: 18),

                _buildFilterSection(),

                const SizedBox(height: 22),

                _buildResultHeader(),

                const SizedBox(height: 12),

                if (_loading)
                  _buildLoading()

                else if (_error != null)
                  _ErrorState(
                    message: _error!,
                    onRetry: _loadHistory,
                  )

                else if (_filteredRequests.isEmpty)
                  const _EmptyState()

                else
                  ..._filteredRequests
                      .map(_buildCard),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return const PageTitle('LỊCH SỬ GÓP Ý');
  }

  // ============================================================
  // FILTER SECTION
  // ============================================================

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: .025,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 19,
                color: hcmuteBlue,
              ),
              SizedBox(width: 8),
              Text(
                'Tìm kiếm & lọc',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // SEARCH
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: hcmuteBlue,
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        )
                      : null,
              hintText:
                  'Tìm theo tiêu đề hoặc nội dung góp ý...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF98A2B3),
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 14,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: borderColor,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide:
                    const BorderSide(
                  color: borderColor,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide:
                    const BorderSide(
                  color: hcmuteBlue,
                  width: 1.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // FILTERS
          LayoutBuilder(
            builder:
                (context, constraints) {
              final bool wide =
                  constraints.maxWidth >= 750;

              if (wide) {
                return Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        value: _status,
                        hint: 'Trạng thái',
                        icon:
                            Icons.flag_outlined,
                        items:
                            _availableStatuses,
                        onChanged: (value) {
                          setState(() {
                            _status =
                                value ?? '';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _dropdown(
                        value:
                            _departmentId,
                        hint: 'Phòng ban',
                        icon: Icons
                            .account_balance_outlined,
                        items:
                            _availableDepartments,
                        onChanged: (value) {
                          setState(() {
                            _departmentId =
                                value ?? '';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _dropdown(
                        value: _categoryId,
                        hint: 'Danh mục',
                        icon:
                            Icons.category_outlined,
                        items:
                            _availableCategories,
                        onChanged: (value) {
                          setState(() {
                            _categoryId =
                                value ?? '';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    _clearButton(),
                  ],
                );
              }

              return Column(
                children: [
                  _dropdown(
                    value: _status,
                    hint: 'Trạng thái',
                    icon:
                        Icons.flag_outlined,
                    items: _availableStatuses,
                    onChanged: (value) {
                      setState(() {
                        _status =
                            value ?? '';
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  _dropdown(
                    value: _departmentId,
                    hint: 'Phòng ban',
                    icon: Icons
                        .account_balance_outlined,
                    items:
                        _availableDepartments,
                    onChanged: (value) {
                      setState(() {
                        _departmentId =
                            value ?? '';
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  _dropdown(
                    value: _categoryId,
                    hint: 'Danh mục',
                    icon:
                        Icons.category_outlined,
                    items:
                        _availableCategories,
                    onChanged: (value) {
                      setState(() {
                        _categoryId =
                            value ?? '';
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: _clearButton(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdown({
    required String value,
    required String hint,
    required IconData icon,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue:
            value.isEmpty ? null : value,
        hint: Text(
          hint,
          style: const TextStyle(
            fontSize: 13,
            color: textSecondary,
          ),
        ),
        isExpanded: true,
        menuMaxHeight: 280,
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            size: 18,
            color: hcmuteBlue,
          ),
          filled: true,
          fillColor:
              const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: borderColor,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: borderColor,
            ),
          ),
        ),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ),
        ],
        onChanged:
            items.isEmpty ? null : onChanged,
      ),
    );
  }

  // ============================================================
  // CLEAR FILTER
  // ============================================================

  Widget _clearButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _searchController.clear();
          _status = '';
          _departmentId = '';
          _categoryId = '';
        });
      },
      icon: const Icon(
        Icons.restart_alt_rounded,
        size: 18,
      ),
      label: const Text('Đặt lại'),
      style: OutlinedButton.styleFrom(
        foregroundColor: hcmuteBlue,
        side: const BorderSide(
          color: hcmuteBlue,
        ),
        minimumSize:
            const Size(110, 46),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(9),
        ),
      ),
    );
  }

  // ============================================================
  // RESULT HEADER
  // ============================================================

  Widget _buildResultHeader() {
    final count =
        _filteredRequests.length;

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Góp ý của bạn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Danh sách các góp ý đã gửi',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: hcmuteLightBlue,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Text(
            '$count góp ý',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hcmuteBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildCard(Request request) {
    final color =
        _statusColor(request.currentStatus);

    final categories = request.categoryIds
        .map(
          (id) => _categories
              .where(
                (category) =>
                    category.id == id,
              )
              .map(
                (category) =>
                    category.subject,
              )
              .firstOrNull,
        )
        .whereType<String>()
        .where(
          (name) => name.isNotEmpty,
        )
        .join(', ');

    return Container(
      margin:
          const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: .035,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(15),
          onTap: () {
            if (widget.onOpenDetail != null) {
              widget.onOpenDetail!(
                request,
                _departments,
                _categories,
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FeedbackDetailPage(
                  request: request,
                  user: widget.user,
                  departments:
                      _departments,
                  categories:
                      _categories,
                ),
              ),
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // TOP
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _StatusPill(
                      label:
                          _statusLabel(
                        request.currentStatus,
                      ),
                      color: color,
                      icon:
                          _statusIcon(
                        request.currentStatus,
                      ),
                    ),

                    const Spacer(),

                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color:
                              textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _date(
                            request.timeCreate,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 11.5,
                            color:
                                textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // TITLE
                Text(
                  request.subject ??
                      'Không có tiêu đề',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight:
                        FontWeight.w800,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                // META
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    _MetaItem(
                      icon: Icons
                          .account_balance_outlined,
                      text:
                          _departmentName(
                        request.departmentId,
                      ),
                    ),
                    _MetaItem(
                      icon:
                          Icons.category_outlined,
                      text: categories.isEmpty
                          ? 'Chưa phân loại'
                          : categories,
                    ),
                  ],
                ),

                // DESCRIPTION
                if (request.description
                        ?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFF8FAFC,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        9,
                      ),
                    ),
                    child: Text(
                      request.description!,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color:
                            textSecondary,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                const Divider(
                  height: 1,
                  color: borderColor,
                ),

                const SizedBox(height: 12),

                // DETAIL BUTTON
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    Text(
                      'Xem chi tiết',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                        color: hcmuteBlue,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 27,
                      height: 27,
                      decoration:
                          BoxDecoration(
                        color:
                            hcmuteLightBlue,
                        borderRadius:
                            BorderRadius.circular(
                          7,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .arrow_forward_rounded,
                        size: 16,
                        color: hcmuteBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: hcmuteBlue,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 13),
            Text(
              'Đang tải lịch sử góp ý...',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// STATUS PILL
// ================================================================

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .09,
        ),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(
            alpha: .20,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// META ITEM
// ================================================================

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: 5,
            color: Color(0xFF98A2B3),
          ),
          const SizedBox(width: 6),
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF667085),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF667085),
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EMPTY
// ================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 55,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 50,
            color: Color(0xFF98A2B3),
          ),
          SizedBox(height: 12),
          Text(
            'Không có góp ý phù hợp',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172B4D),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Hãy thử thay đổi từ khóa hoặc bộ lọc.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFF0D0D0),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Color(0xFFDC2626),
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF667085),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('Thử lại'),
            style:
                OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF005BAA),
              side: const BorderSide(
                color: Color(0xFF005BAA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
