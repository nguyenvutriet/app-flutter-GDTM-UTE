import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'feedback_detail_page.dart';
import '../../models/Category.dart';

import '../../models/ClarificationConversation.dart';

import '../../models/FileAttachment.dart';

import '../../models/Message.dart';

import '../../models/Request.dart';

import '../../models/RequestStatusHistory.dart';

import '../../services/RequestService.dart';
import '../../services/CategoryService.dart';
import 'staff_conversation_dialog.dart';

class StaffListPage extends StatefulWidget {

  final String role;

  final String staffUserId;

  final String? departmentId;

  final String? initialStatus;

  const StaffListPage({

    super.key,

    required this.role,

    required this.staffUserId,

    this.departmentId,

    this.initialStatus,

  });

  @override

  State<StaffListPage> createState() => _StaffListPageState();

}

class _StaffListPageState extends State<StaffListPage> {

  static const Color hcmuteBlue = Color(0xFF005BAA);

  static const Color hcmuteLightBlue = Color(0xFFEAF4FC);

  static const Color pageBackground = Color(0xFFF4F7FB);

  static const Color textPrimary = Color(0xFF172B4D);

  static const Color textSecondary = Color(0xFF667085);

  static const Color borderColor = Color(0xFFE3EAF2);

  final RequestService _service = RequestService();
  final CategoryService _categoryService = CategoryService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;

  String? _error;

  List<Request> _allRequests = [];

  List<Request> _filteredRequests = [];

  String _selectedStatus = 'ALL';

  String _selectedCategory = 'ALL';
  List<Category> _categories = [];
  final Map<String, String> _categoryNamesById = {};

  int _currentPage = 0;

  static const int _pageSize = 12;

  final List<String> _statuses = const [

    'ALL',

    'PENDING',

    'APPROVED',

    'FORWARDING',

    'RESOLVED',

    'REJECTED',

  ];

  @override

  void initState() {

    super.initState();

    _selectedStatus = widget.initialStatus ?? 'ALL';

    _searchController.addListener(_applyFilters);

    _loadRequests();

  }

  @override

  void dispose() {

    _searchController.removeListener(_applyFilters);

    _searchController.dispose();

    super.dispose();

  }

  Future<void> _loadRequests() async {

    if (mounted) {

      setState(() {

        _loading = true;

        _error = null;

      });

    }

    try {

      final results = await Future.wait([
        _service.getStaffFeedbacks(
          role: widget.role,
          departmentId: widget.departmentId,
        ),
        _categoryService.getActiveCategories(),
      ]);

      final data = results[0] as List<Request>;
      final categories = results[1] as List<Category>;

      final categoryMap = <String, String>{};
      for (final category in categories) {
        final id = (category.id ?? '').trim();
        final name = category.subject.trim();
        if (id.isNotEmpty && name.isNotEmpty) {
          categoryMap[id] = name;
        }
      }

      if (!mounted) return;
      setState(() {
        _allRequests = data;
        _categories = categories;
        _categoryNamesById
          ..clear()
          ..addAll(categoryMap);

        if (!_categoryOptions.contains(_selectedCategory)) {
          _selectedCategory = 'ALL';
        }

        _loading = false;
      });

      _applyFilters();

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _loading = false;

        _error = e.toString();

      });

    }

  }

  List<String> get _categoryOptions {
    final result = _categoryNamesById.values
        .where((name) => name.trim().isNotEmpty)
        .map((name) => name.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['ALL', ...result];
  }

  List<String> _requestCategoryIds(Request request) {
    return request.categoryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  List<String> _requestCategoryNames(Request request) {
    final names = <String>{};

    for (final id in _requestCategoryIds(request)) {
      final name = _categoryNamesById[id];
      if (name != null && name.trim().isNotEmpty) {
        names.add(name.trim());
      }
    }

    if (names.isEmpty) {
      for (final category in request.categories) {
        final name = category.subject?.trim() ?? '';
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
    }

    return names.toList();
  }

  Widget _categoryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 14,
            color: textSecondary,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

void _applyFilters() {

    final keyword = _searchController.text.trim().toLowerCase();

    var result = List<Request>.from(_allRequests);

    if (keyword.isNotEmpty) {

      result = result.where((r) {

        final subject = r.subject?.toLowerCase() ?? '';

        final description = r.description?.toLowerCase() ?? '';

        final location = r.location?.toLowerCase() ?? '';

        final userName = r.user?.fullName?.toLowerCase() ?? '';

        return subject.contains(keyword) ||

            description.contains(keyword) ||

            location.contains(keyword) ||

            userName.contains(keyword);

      }).toList();

    }

    if (_selectedStatus != 'ALL') {

      result = result

          .where((r) => r.currentStatus == _selectedStatus)

          .toList();

    }

    if (_selectedCategory != 'ALL') {
      String? selectedId;
      for (final entry in _categoryNamesById.entries) {
        if (entry.value == _selectedCategory) {
          selectedId = entry.key;
          break;
        }
      }

      result = result.where((request) {
        if (selectedId != null) {
          return _requestCategoryIds(request).contains(selectedId);
        }
        return _requestCategoryNames(request).contains(_selectedCategory);
      }).toList();
    }

if (!mounted) return;

    setState(() {

      _filteredRequests = result;

      _currentPage = 0;

    });

  }

  List<Request> get _pageRequests {

    final start = _currentPage * _pageSize;

    if (start >= _filteredRequests.length) return [];

    final end = (start + _pageSize).clamp(0, _filteredRequests.length);

    return _filteredRequests.sublist(start, end);

  }

  int get _totalPages =>

      _filteredRequests.isEmpty ? 1 : (_filteredRequests.length / _pageSize).ceil();

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

      case 'PENDING':

        return Icons.schedule_outlined;

      case 'FORWARDING':

        return Icons.forward_outlined;

      case 'APPROVED':

        return Icons.autorenew_rounded;

      case 'RESOLVED':

        return Icons.check_circle_outline;

      case 'REJECTED':

        return Icons.cancel_outlined;

      default:

        return Icons.info_outline;

    }

  }

  String _date(DateTime? value) {

    if (value == null) return 'Chưa cập nhật';

    final d = value.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';

  }

  Future<void> _openDetail(Request request) async {

    final changed = await showDialog<bool>(

      context: context,

      barrierDismissible: false,

      builder: (_) => _StaffFeedbackDetailDialog(

        request: request,

        staffUserId: widget.staffUserId,

        requestService: _service,

      ),

    );

    if (changed == true) await _loadRequests();

  }

  Widget _statusBadge(String? status) {

    final color = _statusColor(status);

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      decoration: BoxDecoration(

        color: color.withOpacity(.08),

        border: Border.all(color: color.withOpacity(.22)),

        borderRadius: BorderRadius.circular(9),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(_statusIcon(status), size: 16, color: color),

          const SizedBox(width: 6),

          Text(

            _statusLabel(status),

            style: TextStyle(

              color: color,

              fontSize: 12,

              fontWeight: FontWeight.w700,

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildTopHeader() {

    return Container(

      height: 58,

      decoration: BoxDecoration(

        color: Colors.white,

        border: Border(

          bottom: BorderSide(

            color: Colors.grey.shade400,

            width: 3,

          ),

        ),

      ),

      child: Stack(

        clipBehavior: Clip.none,

        children: [

          // Phần đuôi xám phía sau

          Positioned(

            left: 0,

            top: 0,

            bottom: 3,

            child: ClipPath(

              clipper: _HeaderTriangleClipper(),

              child: Container(

                width: 330,

                color: Colors.grey.shade500,

              ),

            ),

          ),

          // Thanh xanh tiêu đề

          Positioned(

            left: 0,

            top: 0,

            bottom: 3,

            child: Container(

              width: 295,

              padding: const EdgeInsets.symmetric(horizontal: 22),

              alignment: Alignment.centerLeft,

              color: hcmuteBlue,

              child: const Text(

                'TIẾP NHẬN GÓP Ý',

                style: TextStyle(

                  color: Colors.white,

                  fontSize: 22,

                  fontWeight: FontWeight.w700,

                  letterSpacing: 0.2,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tiêu đề, nội dung, vị trí, người gửi...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: borderColor),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),

          // Bộ lọc trạng thái
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuses.map((status) {
                final selected = _selectedStatus == status;
                final color =
                    status == 'ALL' ? hcmuteBlue : _statusColor(status);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(
                      status == 'ALL' ? 'Tất cả' : _statusLabel(status),
                    ),
                    selectedColor: color.withOpacity(.12),
                    side: BorderSide(
                      color: selected
                          ? color.withOpacity(.35)
                          : borderColor,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? color : textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedStatus = status);
                      _applyFilters();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Bộ lọc danh mục
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Danh mục',
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: borderColor),
              ),
            ),
            items: _categoryOptions.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(
                  category == 'ALL' ? 'Tất cả danh mục' : category,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Request request) {

    return Container(

      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor),

        boxShadow: const [

          BoxShadow(

            color: Color(0x09172B4D),

            blurRadius: 12,

            offset: Offset(0, 4),

          ),

        ],

      ),

      child: InkWell(

        borderRadius: BorderRadius.circular(16),

        onTap: () => _openDetail(request),

        child: Padding(

          padding: const EdgeInsets.all(18),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Expanded(

                    child: Text(

                      request.subject?.trim().isNotEmpty == true

                          ? request.subject!

                          : 'Không có tiêu đề',

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(

                        color: textPrimary,

                        fontSize: 17,

                        fontWeight: FontWeight.w800,

                      ),

                    ),

                  ),

                  const SizedBox(width: 12),

                  _statusBadge(request.currentStatus),

                ],

              ),

              const SizedBox(height: 13),

              Text(

                request.description?.trim().isNotEmpty == true

                    ? request.description!

                    : 'Không có nội dung mô tả.',

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(

                  color: textSecondary,

                  height: 1.45,

                  fontSize: 13.5,

                ),

              ),

              const SizedBox(height: 15),

              Wrap(

                spacing: 16,

                runSpacing: 8,

                children: [

                  _miniInfo(

                    Icons.person_outline,

                    request.user?.fullName ?? request.userId ?? 'Người gửi',

                  ),

                  if ((request.location ?? '').trim().isNotEmpty)

                    _miniInfo(Icons.location_on_outlined, request.location!),

                  _miniInfo(Icons.schedule_outlined, _date(request.timeCreate)),

                ],

              ),

              const SizedBox(height: 13),

                            const SizedBox(height: 12),

              // Chỉ hiển thị danh mục, không hiển thị tên phòng ban.
              Builder(
                builder: (_) {
                  final categories = _requestCategoryNames(request);

                  if (categories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: categories
                        .map((category) => _categoryChip(category))
                        .toList(),
                  );
                },
              ),

const Divider(height: 1, color: borderColor),

              const SizedBox(height: 11),

              Row(

                children: [

                  const Text(

                    'Xem chi tiết',

                    style: TextStyle(

                      color: hcmuteBlue,

                      fontWeight: FontWeight.w700,

                      fontSize: 13,

                    ),

                  ),

                  const Spacer(),

                  const Icon(

                    Icons.arrow_forward_rounded,

                    color: hcmuteBlue,

                    size: 18,

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }

  Widget _miniInfo(IconData icon, String text) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Icon(icon, size: 16, color: textSecondary),

        const SizedBox(width: 5),

        ConstrainedBox(

          constraints: const BoxConstraints(maxWidth: 260),

          child: Text(

            text,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(color: textSecondary, fontSize: 12.5),

          ),

        ),

      ],

    );

  }

  Widget _buildPagination() {

    if (_filteredRequests.isEmpty) return const SizedBox.shrink();

    return Padding(

      padding: const EdgeInsets.only(top: 6, bottom: 12),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          IconButton(

            onPressed: _currentPage <= 0

                ? null

                : () => setState(() => _currentPage--),

            icon: const Icon(Icons.chevron_left_rounded),

          ),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(9),

              border: Border.all(color: borderColor),

            ),

            child: Text(

              'Trang ${_currentPage + 1} / $_totalPages',

              style: const TextStyle(

                color: textPrimary,

                fontWeight: FontWeight.w700,

              ),

            ),

          ),

          IconButton(

            onPressed: _currentPage >= _totalPages - 1

                ? null

                : () => setState(() => _currentPage++),

            icon: const Icon(Icons.chevron_right_rounded),

          ),

        ],

      ),

    );

  }

  Widget _buildBody() {

    if (_loading) {

      return const Center(

        child: CircularProgressIndicator(color: hcmuteBlue),

      );

    }

    if (_error != null) {

      return Center(

        child: Container(

          constraints: const BoxConstraints(maxWidth: 520),

          padding: const EdgeInsets.all(28),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: borderColor),

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 52),

              const SizedBox(height: 12),

              const Text(

                'Không thể tải danh sách góp ý',

                style: TextStyle(

                  color: textPrimary,

                  fontSize: 18,

                  fontWeight: FontWeight.w800,

                ),

              ),

              const SizedBox(height: 8),

              Text(

                _error!,

                textAlign: TextAlign.center,

                style: const TextStyle(color: textSecondary),

              ),

              const SizedBox(height: 18),

              FilledButton.icon(

                onPressed: _loadRequests,

                icon: const Icon(Icons.refresh),

                label: const Text('Thử lại'),

              ),

            ],

          ),

        ),

      );

    }

    if (_filteredRequests.isEmpty) {

      return RefreshIndicator(

        onRefresh: _loadRequests,

        child: ListView(

          children: const [

            SizedBox(height: 120),

            Icon(Icons.inbox_outlined, size: 68, color: Color(0xFF98A2B3)),

            SizedBox(height: 16),

            Center(

              child: Text(

                'Không có góp ý nào',

                style: TextStyle(

                  color: textPrimary,

                  fontSize: 17,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ),

            SizedBox(height: 6),

            Center(

              child: Text(

                'Thử thay đổi từ khóa hoặc bộ lọc.',

                style: TextStyle(color: textSecondary),

              ),

            ),

          ],

        ),

      );

    }

    return RefreshIndicator(

      onRefresh: _loadRequests,

      child: ListView.builder(

        padding: const EdgeInsets.only(bottom: 8),

        itemCount: _pageRequests.length,

        itemBuilder: (_, index) => _buildRequestCard(_pageRequests[index]),

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return Container(

      color: pageBackground,

      child: LayoutBuilder(

        builder: (context, constraints) {

          final desktop = constraints.maxWidth >= 900;

          final horizontal = desktop ? 42.0 : 16.0;

          return Padding(

            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 20),

            child: Column(

              children: [

                _buildTopHeader(),

                const SizedBox(height: 16),

                _buildSearchAndFilter(),

                const SizedBox(height: 16),

                Expanded(child: _buildBody()),

                _buildPagination(),

              ],

            ),

          );

        },

      ),

    );

  }

}

class _StaffFeedbackDetailDialog extends StatefulWidget {

  final Request request;

  final String staffUserId;

  final RequestService requestService;

  const _StaffFeedbackDetailDialog({

    required this.request,

    required this.staffUserId,

    required this.requestService,

  });

  @override

  State<_StaffFeedbackDetailDialog> createState() =>

      _StaffFeedbackDetailDialogState();

}

class _StaffFeedbackDetailDialogState

    extends State<_StaffFeedbackDetailDialog> {

  static const Color hcmuteBlue = Color(0xFF005BAA);

  static const Color hcmuteLightBlue = Color(0xFFEAF4FC);

  static const Color pageBackground = Color(0xFFF4F7FB);

  static const Color textPrimary = Color(0xFF172B4D);

  static const Color textSecondary = Color(0xFF667085);

  static const Color borderColor = Color(0xFFE3EAF2);

  late Request _request;

  FeedbackDetails? _details;

  bool _loading = true;

  bool _processing = false;

  String? _error;

  List<_DepartmentOption> _departments = [];

  @override

  void initState() {

    super.initState();

    _request = widget.request;

    _loadDetails();

  }

  Future<void> _loadDetails() async {

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final results = await Future.wait([

        widget.requestService.getFeedbackDetails(_request),

        _loadDepartments(),

      ]);

      if (!mounted) return;

      setState(() {

        _details = results[0] as FeedbackDetails;

        _departments = results[1] as List<_DepartmentOption>;

        _loading = false;

      });

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _loading = false;

        _error = e.toString();

      });

    }

  }

  Future<List<_DepartmentOption>> _loadDepartments() async {

    final firestore = FirebaseFirestore.instance;

    final results = <_DepartmentOption>[];

    Future<void> readCollection(String name) async {

      try {

        final snapshot = await firestore.collection(name).get();

        for (final doc in snapshot.docs) {

          final data = doc.data();

          final id = doc.id;

          final nameValue = (data['name'] ??

                  data['departmentName'] ??

                  data['title'] ??

                  '')

              .toString()

              .trim();

          if (nameValue.isNotEmpty &&

              !results.any((item) => item.id == id)) {

            results.add(_DepartmentOption(id: id, name: nameValue));

          }

        }

      } catch (_) {}

    }

    await readCollection('departments');

    if (results.isEmpty) await readCollection('department');

    results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return results;

  }

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

      case 'PENDING':

        return Icons.schedule_outlined;

      case 'FORWARDING':

        return Icons.forward_outlined;

      case 'APPROVED':

        return Icons.autorenew_rounded;

      case 'RESOLVED':

        return Icons.check_circle_outline;

      case 'REJECTED':

        return Icons.cancel_outlined;

      default:

        return Icons.info_outline;

    }

  }

  String _date(DateTime? value) {

    if (value == null) return 'Chưa cập nhật';

    final d = value.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';

  }

  Future<void> _changeStatus() async {

    final current = _request.currentStatus;

    List<String> allowed;

    switch (current) {

      case 'PENDING':

        allowed = const ['APPROVED', 'RESOLVED', 'REJECTED'];

        break;

      case 'APPROVED':

        allowed = const ['RESOLVED', 'REJECTED', 'FORWARDING'];

        break;

      default:

        allowed = const [];

    }

    if (allowed.isEmpty) {

      _showMessage('Góp ý này không thể thay đổi trạng thái.');

      return;

    }

    String? selected = await showDialog<String>(

      context: context,

      builder: (dialogContext) => AlertDialog(

        title: const Text('Cập nhật trạng thái'),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: allowed.map((status) {

            final color = _statusColor(status);

            return ListTile(

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(10),

              ),

              leading: Icon(_statusIcon(status), color: color),

              title: Text(_statusLabel(status)),

              onTap: () => Navigator.pop(dialogContext, status),

            );

          }).toList(),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(dialogContext),

            child: const Text('Hủy'),

          ),

        ],

      ),

    );

    if (selected == null) return;

    await _updateStatus(selected);

  }

  Future<void> _updateStatus(String newStatus) async {

    final requestId = _request.id;

    if (requestId == null || requestId.isEmpty) {

      _showMessage('Không xác định được ID góp ý.');

      return;

    }

    try {

      setState(() => _processing = true);

      await widget.requestService.updateStaffStatus(

        requestId: requestId,

        newStatus: newStatus,

        staffUserId: widget.staffUserId,

      );

      _request = _request.copyWith(currentStatus: newStatus);

      await _loadDetails();

      if (!mounted) return;

      setState(() => _processing = false);

      _showMessage('Đã chuyển sang "${_statusLabel(newStatus)}".');

    } catch (e) {

      if (!mounted) return;

      setState(() => _processing = false);

      _showMessage('Không thể cập nhật trạng thái: $e');

    }

  }

  Future<void> _forwardRequest() async {

    final available = _departments

        .where((d) => d.id != _request.departmentId)

        .toList();

    if (available.isEmpty) {

      _showMessage('Chưa có phòng ban khác để chuyển tiếp.');

      return;

    }

    String? selectedId;

    final noteController = TextEditingController();

    final result = await showDialog<_ForwardResult>(

      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(

          builder: (context, setDialogState) {

            return AlertDialog(

              title: const Row(

                children: [

                  Icon(Icons.forward_outlined, color: hcmuteBlue),

                  SizedBox(width: 10),

                  Text('Chuyển tiếp phản hồi'),

                ],

              ),

              content: SizedBox(

                width: 520,

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Chọn phòng ban muốn chuyển tiếp phản hồi này đến.',

                      style: TextStyle(color: textSecondary),

                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(

                      value: selectedId,

                      isExpanded: true,

                      decoration: InputDecoration(

                        labelText: 'Phòng ban nhận',

                        prefixIcon: const Icon(Icons.business_outlined),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(10),

                        ),

                      ),

                      items: available

                          .map(

                            (department) => DropdownMenuItem<String>(

                              value: department.id,

                              child: Text(

                                department.name,

                                overflow: TextOverflow.ellipsis,

                              ),

                            ),

                          )

                          .toList(),

                      onChanged: (value) {

                        setDialogState(() => selectedId = value);

                      },

                    ),

                    const SizedBox(height: 14),

                    TextField(

                      controller: noteController,

                      maxLines: 4,

                      decoration: InputDecoration(

                        labelText: 'Ghi chú (không bắt buộc)',

                        alignLabelWithHint: true,

                        prefixIcon: const Padding(

                          padding: EdgeInsets.only(bottom: 55),

                          child: Icon(Icons.notes_outlined),

                        ),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(10),

                        ),

                      ),

                    ),

                  ],

                ),

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(dialogContext),

                  child: const Text('Hủy'),

                ),

                FilledButton.icon(

                  onPressed: selectedId == null

                      ? null

                      : () {

                          Navigator.pop(

                            dialogContext,

                            _ForwardResult(

                              departmentId: selectedId!,

                              note: noteController.text.trim(),

                            ),

                          );

                        },

                  icon: const Icon(Icons.send_rounded),

                  label: const Text('Chuyển tiếp'),

                ),

              ],

            );

          },

        );

      },

    );

    noteController.dispose();

    if (result == null) return;

    final requestId = _request.id;

    if (requestId == null || requestId.isEmpty) {

      _showMessage('Không xác định được ID góp ý.');

      return;

    }

    try {

      setState(() => _processing = true);

      await widget.requestService.forwardRequest(

        requestId: requestId,

        toDepartmentId: result.departmentId,

        staffUserId: widget.staffUserId,

        note: result.note.isEmpty ? null : result.note,

      );

      await _loadDetails();

      if (!mounted) return;

      setState(() => _processing = false);

      _showMessage('Đã chuyển tiếp phản hồi thành công.');

    } catch (e) {

      if (!mounted) return;

      setState(() => _processing = false);

      _showMessage('Không thể chuyển tiếp phản hồi: $e');

    }

  }

  void _showMessage(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message)),

    );

  }

  Widget _sectionCard({

    required IconData icon,

    required String title,

    required Widget child,

  }) {

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 16),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor),

        boxShadow: const [

          BoxShadow(

            color: Color(0x09172B4D),

            blurRadius: 14,

            offset: Offset(0, 4),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 38,

                height: 38,

                decoration: BoxDecoration(

                  color: hcmuteLightBlue,

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Icon(icon, color: hcmuteBlue, size: 20),

              ),

              const SizedBox(width: 11),

              Text(

                title,

                style: const TextStyle(

                  color: textPrimary,

                  fontSize: 17,

                  fontWeight: FontWeight.w800,

                ),

              ),

            ],

          ),

          const SizedBox(height: 18),

          child,

        ],

      ),

    );

  }

  Widget _infoItem(IconData icon, String label, String value) {

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: borderColor),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(

            width: 34,

            height: 34,

            decoration: BoxDecoration(

              color: hcmuteLightBlue,

              borderRadius: BorderRadius.circular(9),

            ),

            child: Icon(icon, size: 18, color: hcmuteBlue),

          ),

          const SizedBox(width: 10),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  label,

                  style: const TextStyle(

                    color: textSecondary,

                    fontSize: 11,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(height: 3),

                Text(

                  value.isEmpty ? 'Chưa cập nhật' : value,

                  style: const TextStyle(

                    color: textPrimary,

                    fontSize: 13.5,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildSummary() {

    final color = _statusColor(_request.currentStatus);

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor),

        boxShadow: const [

          BoxShadow(

            color: Color(0x09172B4D),

            blurRadius: 14,

            offset: Offset(0, 4),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(

            height: 5,

            decoration: BoxDecoration(

              color: hcmuteBlue,

              borderRadius: BorderRadius.circular(10),

            ),

          ),

          const SizedBox(height: 17),

          Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Expanded(

                child: Text(

                  _request.subject?.trim().isNotEmpty == true

                      ? _request.subject!

                      : 'Chi tiết góp ý',

                  style: const TextStyle(

                    color: textPrimary,

                    fontSize: 21,

                    fontWeight: FontWeight.w800,

                  ),

                ),

              ),

              const SizedBox(width: 12),

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

                decoration: BoxDecoration(

                  color: color.withOpacity(.08),

                  border: Border.all(color: color.withOpacity(.22)),

                  borderRadius: BorderRadius.circular(9),

                ),

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Icon(_statusIcon(_request.currentStatus), size: 17, color: color),

                    const SizedBox(width: 6),

                    Text(

                      _statusLabel(_request.currentStatus),

                      style: TextStyle(

                        color: color,

                        fontSize: 12,

                        fontWeight: FontWeight.w800,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 14),

          Row(

            children: [

              _privacyBadge(),

              const SizedBox(width: 8),

              Text(

                _date(_request.timeCreate),

                style: const TextStyle(color: textSecondary, fontSize: 12),

              ),

            ],

          ),

          const SizedBox(height: 18),

          const Divider(color: borderColor, height: 1),

          const SizedBox(height: 16),

          _infoItem(

            Icons.person_outline,

            'Người gửi',

            _request.user?.fullName ?? _request.userId ?? 'Không xác định',

          ),

          _infoItem(

            Icons.email_outlined,

            'Email',

            _request.user?.email ?? '',

          ),

          _infoItem(

            Icons.business_outlined,

            'Phòng ban hiện tại',

            _departmentName(_request.departmentId),

          ),

          _infoItem(

            Icons.location_on_outlined,

            'Địa điểm',

            _request.location ?? '',

          ),

        ],

      ),

    );

  }

  Widget _privacyBadge() {

    final isPublic = (_request.postStatus ?? '').toUpperCase() == 'PUBLIC';

    final color = isPublic ? hcmuteBlue : const Color(0xFF667085);

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(

        color: color.withOpacity(.08),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withOpacity(.18)),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(

            isPublic ? Icons.public_outlined : Icons.lock_outline,

            size: 14,

            color: color,

          ),

          const SizedBox(width: 5),

          Text(

            isPublic ? 'Công khai' : 'Riêng tư',

            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),

          ),

        ],

      ),

    );

  }

  String _departmentName(String? id) {

    if (id == null || id.isEmpty) return 'Chưa xác định';

    for (final d in _departments) {

      if (d.id == id) return d.name;

    }

    return id;

  }

  Widget _buildDescription() {

    return _sectionCard(

      icon: Icons.description_outlined,

      title: 'Nội dung phản hồi',

      child: Text(

        (_request.description ?? '').trim().isEmpty

            ? 'Không có nội dung.'

            : _request.description!,

        style: const TextStyle(

          color: textPrimary,

          fontSize: 14,

          height: 1.65,

        ),

      ),

    );

  }

  Widget _buildAttachments() {

    final files = _details?.attachments ?? <FileAttachment>[];

    return _sectionCard(

      icon: Icons.attach_file_rounded,

      title: 'Tệp đính kèm',

      child: files.isEmpty

          ? const Text(

              'Không có tệp đính kèm.',

              style: TextStyle(color: textSecondary),

            )

          : Column(

              children: files.map((file) {

                return Container(

                  margin: const EdgeInsets.only(bottom: 9),

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: const Color(0xFFF8FAFC),

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(color: borderColor),

                  ),

                  child: Row(

                    children: [

                      const Icon(Icons.insert_drive_file_outlined, color: hcmuteBlue),

                      const SizedBox(width: 10),

                      Expanded(

                        child: Text(

                          file.filename ?? 'Tệp đính kèm',

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(

                            color: textPrimary,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                      ),

                      if ((file.filesize ?? 0) > 0)

                        Text(

                          _fileSize(file.filesize!),

                          style: const TextStyle(color: textSecondary, fontSize: 11),

                        ),

                    ],

                  ),

                );

              }).toList(),

            ),

    );

  }

  String _fileSize(int bytes) {

    if (bytes < 1024) return '$bytes B';

    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  }

  Widget _buildActionCard() {

    final canForward = _request.currentStatus == 'APPROVED';

    return _sectionCard(

      icon: Icons.admin_panel_settings_outlined,

      title: 'Xử lý phản hồi',

      child: Wrap(

        spacing: 10,

        runSpacing: 10,

        children: [

          FilledButton.icon(

            onPressed: _processing ? null : _changeStatus,

            icon: const Icon(Icons.sync_alt_rounded),

            label: const Text('Cập nhật trạng thái'),

          ),

          OutlinedButton.icon(

            onPressed: _processing || !canForward ? null : _forwardRequest,

            icon: const Icon(Icons.forward_outlined),

            label: const Text('Chuyển tiếp'),

          ),

          OutlinedButton.icon(

            onPressed: _processing ? null : _openMessages,

            icon: const Icon(Icons.forum_outlined),

            label: const Text('Xem trao đổi'),

          ),

        ],

      ),

    );

  }

  Future<void> _openMessages() async {
    // Trao đổi do StaffConversationDialog tự tải theo thời gian thực.
    await showDialog(
      context: context,
      builder: (_) => StaffConversationDialog(
        request: _request,
        staffUserId: widget.staffUserId,
      ),
    );
  }

  Widget _buildHistory() {

    final histories = List<RequestStatusHistory>.from(_details?.histories ?? [])

      ..sort((a, b) => (b.createAt ?? DateTime(0)).compareTo(a.createAt ?? DateTime(0)));

    return _sectionCard(

      icon: Icons.timeline_outlined,

      title: 'Lịch sử xử lý',

      child: histories.isEmpty

          ? const Text(

              'Chưa có lịch sử trạng thái.',

              style: TextStyle(color: textSecondary),

            )

          : Column(

              children: List.generate(

                histories.length,

                (index) => _timelineItem(

                  histories[index],

                  isLast: index == histories.length - 1,

                ),

              ),

            ),

    );

  }

  Widget _timelineItem(RequestStatusHistory history, {required bool isLast}) {

    final color = _statusColor(history.status);

    return IntrinsicHeight(

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 34,

            child: Column(

              children: [

                Container(

                  width: 32,

                  height: 32,

                  decoration: BoxDecoration(

                    color: color.withOpacity(.1),

                    shape: BoxShape.circle,

                  ),

                  child: Icon(_statusIcon(history.status), color: color, size: 17),

                ),

                if (!isLast)

                  Expanded(

                    child: Container(

                      width: 2,

                      margin: const EdgeInsets.symmetric(vertical: 5),

                      color: borderColor,

                    ),

                  ),

              ],

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Container(

              margin: const EdgeInsets.only(bottom: 12),

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(

                color: const Color(0xFFF8FAFC),

                borderRadius: BorderRadius.circular(11),

                border: Border.all(color: borderColor),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    _statusLabel(history.status),

                    style: TextStyle(

                      color: color,

                      fontWeight: FontWeight.w800,

                      fontSize: 13,

                    ),

                  ),

                  const SizedBox(height: 4),

                  Text(

                    _date(history.createAt),

                    style: const TextStyle(color: textSecondary, fontSize: 11.5),

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildContent() {

    if (_loading) {

      return const Center(

        child: CircularProgressIndicator(color: hcmuteBlue),

      );

    }

    if (_error != null) {

      return Center(

        child: Padding(

          padding: const EdgeInsets.all(28),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 52),

              const SizedBox(height: 12),

              const Text(

                'Không thể tải chi tiết góp ý',

                style: TextStyle(

                  color: textPrimary,

                  fontSize: 18,

                  fontWeight: FontWeight.w800,

                ),

              ),

              const SizedBox(height: 8),

              Text(_error!, textAlign: TextAlign.center),

              const SizedBox(height: 16),

              FilledButton.icon(

                onPressed: _loadDetails,

                icon: const Icon(Icons.refresh),

                label: const Text('Thử lại'),

              ),

            ],

          ),

        ),

      );

    }

    return SingleChildScrollView(

      padding: const EdgeInsets.all(22),

      child: Column(

        children: [

          _buildSummary(),

          _buildDescription(),

          _buildAttachments(),

          _buildActionCard(),

          _buildHistory(),

        ],

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return Dialog(

      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),

      backgroundColor: pageBackground,

      clipBehavior: Clip.antiAlias,

      child: ConstrainedBox(

        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 850),

        child: Column(

          children: [

            Container(

              padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),

              color: Colors.white,

              child: Row(

                children: [

                  Container(

                    width: 42,

                    height: 42,

                    decoration: BoxDecoration(

                      color: hcmuteLightBlue,

                      borderRadius: BorderRadius.circular(11),

                    ),

                    child: const Icon(Icons.feedback_outlined, color: hcmuteBlue),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Text(

                      _request.subject?.trim().isNotEmpty == true

                          ? _request.subject!

                          : 'Chi tiết góp ý',

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(

                        color: textPrimary,

                        fontSize: 19,

                        fontWeight: FontWeight.w800,

                      ),

                    ),

                  ),

                  IconButton(

                    onPressed: _processing

                        ? null

                        : () => Navigator.pop(context, false),

                    icon: const Icon(Icons.close_rounded),

                  ),

                ],

              ),

            ),

            const Divider(height: 1, color: borderColor),

            Expanded(child: _buildContent()),

            Container(

              padding: const EdgeInsets.all(14),

              color: Colors.white,

              child: Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  OutlinedButton(

                    onPressed: _processing

                        ? null

                        : () => Navigator.pop(context, true),

                    child: const Text('Đóng'),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

}

class _DepartmentOption {

  final String id;

  final String name;

  const _DepartmentOption({required this.id, required this.name});

}

class _ForwardResult {

  final String departmentId;

  final String note;

  const _ForwardResult({required this.departmentId, required this.note});

}

class _ConversationDialog extends StatelessWidget {

  final List<ClarificationConversation> conversations;

  const _ConversationDialog({required this.conversations});

  String _date(DateTime? value) {

    if (value == null) return '';

    final d = value.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';

  }

  Widget _message(Message message) {

    return Container(

      margin: const EdgeInsets.only(bottom: 9),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: const Color(0xFFE3EAF2)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'Người gửi',

            style: const TextStyle(

              color: Color(0xFF172B4D),

              fontWeight: FontWeight.w700,

              fontSize: 12,

            ),

          ),

          const SizedBox(height: 5),

          Text(message.content ?? ''),

          if (message.createAt != null) ...[

            const SizedBox(height: 5),

            Text(

              _date(message.createAt),

              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),

            ),

          ],

        ],

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Row(

        children: [

          Icon(Icons.forum_outlined, color: Color(0xFF005BAA)),

          SizedBox(width: 9),

          Text('Trao đổi với sinh viên'),

        ],

      ),

      content: SizedBox(

        width: 650,

        height: 500,

        child: conversations.isEmpty

            ? const Center(

                child: Text(

                  'Chưa có cuộc trao đổi nào.',

                  style: TextStyle(color: Color(0xFF667085)),

                ),

              )

            : ListView.builder(

                itemCount: conversations.length,

                itemBuilder: (_, index) {

                  final conversation = conversations[index];

                  final open = conversation.isOpen ?? false;

                  return Container(

                    margin: const EdgeInsets.only(bottom: 14),

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(13),

                      border: Border.all(color: const Color(0xFFE3EAF2)),

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Row(

                          children: [

                            Expanded(

                              child: Text(

                                conversation.subject ?? 'Cuộc trao đổi',

                                style: const TextStyle(

                                  color: Color(0xFF172B4D),

                                  fontWeight: FontWeight.w800,

                                ),

                              ),

                            ),

                            Container(

                              padding: const EdgeInsets.symmetric(

                                horizontal: 9,

                                vertical: 5,

                              ),

                              decoration: BoxDecoration(

                                color: (open ? Colors.green : Colors.grey)

                                    .withOpacity(.1),

                                borderRadius: BorderRadius.circular(20),

                              ),

                              child: Text(

                                open ? 'Đang mở' : 'Đã đóng',

                                style: TextStyle(

                                  color: open ? Colors.green : Colors.grey,

                                  fontSize: 11,

                                  fontWeight: FontWeight.w700,

                                ),

                              ),

                            ),

                          ],

                        ),

                        const SizedBox(height: 12),

                        ...conversation.messages.map(_message),

                      ],

                    ),

                  );

                },

              ),

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.pop(context),

          child: const Text('Đóng'),

        ),

      ],

    );

  }

}

class _HeaderTriangleClipper extends CustomClipper<Path> {

  @override

  Path getClip(Size size) {

    final path = Path();

    path.moveTo(0, 0);

    path.lineTo(size.width - 20, 0);

    path.lineTo(size.width - 42, size.height);

    path.lineTo(0, size.height);

    path.close();

    return path;

  }

  @override

  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {

    return false;

  }

}
