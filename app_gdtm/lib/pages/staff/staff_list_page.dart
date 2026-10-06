import 'package:app_gdtm/pages/staff/feedback_detail_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ClarificationConversation.dart';

import '../../models/FileAttachment.dart';

import '../../models/Message.dart';

import '../../models/Request.dart';

import '../../models/RequestStatusHistory.dart';

import '../../services/RequestService.dart';

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

  StreamSubscription<List<Request>>? _requestsSubscription;

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;

  String? _error;

  List<Request> _allRequests = [];

  List<Request> _filteredRequests = [];

  String _selectedStatus = 'ALL';

  String _selectedCategory = 'ALL';

  final Map<String, String> _categoryNamesById = {};

  final ScrollController _scrollController = ScrollController();

  int _visibleCount = 12;

  static const int _loadMoreCount = 12;

  bool _loadingMore = false;

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

    _scrollController.addListener(_onScroll);

    _loadRequests();

  }

  @override

    void dispose() {

    _requestsSubscription?.cancel();

    _searchController.removeListener(_applyFilters);

    _scrollController.removeListener(_onScroll);

    _scrollController.dispose();

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

    await _requestsSubscription?.cancel();

    _requestsSubscription = _service
        .watchStaffFeedbacks(
          role: widget.role,
          departmentId: widget.departmentId,
        )
        .listen(
          (data) {
            if (!mounted) return;

            setState(() {
              _allRequests = data;

              if (!_categoryOptions.contains(_selectedCategory)) {
                _selectedCategory = 'ALL';
              }

              _loading = false;
              _error = null;
            });

            _applyFilters();
          },
          onError: (error) {
            if (!mounted) return;

            setState(() {
              _loading = false;
              _error = error.toString();
            });
          },
        );

    try {
      final categorySnapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      final categoryMap = <String, String>{};

      for (final doc in categorySnapshot.docs) {
        final value = doc.data();

        final id = (value['id'] ?? doc.id).toString().trim();

        final name =
            (value['subject'] ?? value['name'] ?? value['title'] ?? '')
                .toString()
                .trim();

        if (id.isNotEmpty && name.isNotEmpty) {
          categoryMap[id] = name;
        }
      }

      if (!mounted) return;

      setState(() {
        _categoryNamesById
          ..clear()
          ..addAll(categoryMap);
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }
  }

  List<String> get _categoryOptions {

    final names = <String>{};

    for (final request in _allRequests) {

      names.addAll(_requestCategoryNames(request));

    }

    final result = names

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

  void _resetFilters() {

    _searchController.clear();

    setState(() {

      _selectedStatus = 'ALL';

      _selectedCategory = 'ALL';

      _visibleCount = _loadMoreCount.clamp(0, _filteredRequests.length);

    });

    _applyFilters();

  }

  void _onScroll() {

    if (!_scrollController.hasClients || _loadingMore) return;

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 500) {

      _loadMore();

    }

  }

  void _loadMore() {

    if (_loadingMore || _visibleCount >= _filteredRequests.length) return;

    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 250), () {

      if (!mounted) return;

      setState(() {

        _visibleCount = (_visibleCount + _loadMoreCount)

            .clamp(0, _filteredRequests.length);

        _loadingMore = false;

      });

    });

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

    // Mặc định: mới nhất trước.

    result.sort((a, b) {

      final aTime = a.timeCreate;

      final bTime = b.timeCreate;

      if (aTime == null && bTime == null) return 0;

      if (aTime == null) return 1;

      if (bTime == null) return -1;

      return bTime.compareTo(aTime);

    });

    if (!mounted) return;

    setState(() {

      _filteredRequests = result;

      _visibleCount = _loadMoreCount.clamp(0, result.length);

    });

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

  Future<void> _openDetail(Request request) async {

    final changed = await Navigator.push<bool>(

      context,

      MaterialPageRoute(

        builder: (_) => FeedbackDetailPage(

          request: request,

          role: widget.role,

          departmentId: widget.departmentId,

          departments: const [],

          staffUserId: widget.staffUserId,

        ),

      ),

    );

    if (changed == true && mounted) {

      await _loadRequests();

    }

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

              clipper: _StaffHeaderTriangleClipper(),

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

          DropdownButtonFormField<String>(

            value: _selectedStatus,

            isExpanded: true,

            decoration: InputDecoration(

              labelText: 'Trạng thái',

              prefixIcon: const Icon(Icons.filter_alt_outlined),

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

            items: _statuses.map((status) {

              return DropdownMenuItem<String>(

                value: status,

                child: Text(

                  status == 'ALL' ? 'Tất cả trạng thái' : _statusLabel(status),

                  overflow: TextOverflow.ellipsis,

                ),

              );

            }).toList(),

            onChanged: (value) {

              if (value == null) return;

              setState(() => _selectedStatus = value);

              _applyFilters();

            },

          ),

          const SizedBox(height: 12),

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

          const SizedBox(height: 14),

          SizedBox(

            width: double.infinity,

            child: OutlinedButton.icon(

              onPressed: _resetFilters,

              icon: const Icon(Icons.restart_alt_rounded, size: 18),

              label: const Text('Đặt lại bộ lọc'),

            ),

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

              Builder(

                builder: (_) {

                  final categories = _requestCategoryNames(request);

                  if (categories.isEmpty) {

                    return const SizedBox.shrink();

                  }

                  return Padding(

                    padding: const EdgeInsets.only(top: 10, bottom: 2),

                    child: Wrap(

                      spacing: 8,

                      runSpacing: 7,

                      children: categories

                          .map((category) => _categoryChip(category))

                          .toList(),

                    ),

                  );

                },

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

      Widget _buildBody({required double horizontal}) {

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

              const Icon(

                Icons.error_outline,

                color: Color(0xFFDC2626),

                size: 52,

              ),

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

          controller: _scrollController,

          physics: const AlwaysScrollableScrollPhysics(),

          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),

          children: [

            _buildTopHeader(),

            Padding(

              padding: const EdgeInsets.only(top: 16, bottom: 16),

              child: _buildSearchAndFilter(),

            ),

            const SizedBox(height: 90),

            const Icon(

              Icons.inbox_outlined,

              size: 68,

              color: Color(0xFF98A2B3),

            ),

            const SizedBox(height: 16),

            const Center(

              child: Text(

                'Không có góp ý nào',

                style: TextStyle(

                  color: textPrimary,

                  fontSize: 17,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ),

            const SizedBox(height: 6),

            const Center(

              child: Text(

                'Thử thay đổi từ khóa hoặc bộ lọc.',

                style: TextStyle(color: textSecondary),

              ),

            ),

          ],

        ),

      );

    }

    final visibleCount = _visibleCount.clamp(0, _filteredRequests.length);

    final hasMore = visibleCount < _filteredRequests.length;

    return RefreshIndicator(

      onRefresh: _loadRequests,

      child: ListView.builder(

        controller: _scrollController,

        physics: const AlwaysScrollableScrollPhysics(),

        padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),

        itemCount: 2 + visibleCount + (hasMore || _loadingMore ? 1 : 0),

        itemBuilder: (context, index) {

          if (index == 0) {

            return _buildTopHeader();

          }

          if (index == 1) {

            return Padding(

              padding: const EdgeInsets.only(top: 16, bottom: 16),

              child: _buildSearchAndFilter(),

            );

          }

          final requestIndex = index - 2;

          if (requestIndex < visibleCount) {

            return _buildRequestCard(_filteredRequests[requestIndex]);

          }

          if (_loadingMore) {

            return const Padding(

              padding: EdgeInsets.symmetric(vertical: 20),

              child: Center(

                child: SizedBox(

                  width: 24,

                  height: 24,

                  child: CircularProgressIndicator(

                    strokeWidth: 2.5,

                    color: hcmuteBlue,

                  ),

                ),

              ),

            );

          }

          return const Padding(

            padding: EdgeInsets.symmetric(vertical: 18),

            child: Center(

              child: Text(

                'Đã tải hết danh sách góp ý',

                style: TextStyle(

                  color: textSecondary,

                  fontSize: 12.5,

                ),

              ),

            ),

          );

        },

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

          return _buildBody(horizontal: horizontal);

        },

      ),

    );

  }

}

/// Tạo phần đuôi tam giác cho thanh tiêu đề màu xám.

class _StaffHeaderTriangleClipper extends CustomClipper<Path> {

  @override

  Path getClip(Size size) {

    final path = Path();

    path.moveTo(0, 0);

    path.lineTo(size.width, 0);

    path.lineTo(size.width - 45, size.height);

    path.lineTo(0, size.height);

    path.close();

    return path;

  }

  @override

  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;

}
