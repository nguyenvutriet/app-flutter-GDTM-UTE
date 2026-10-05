import 'package:flutter/material.dart';

import 'staff_list_page.dart';

import '../../services/RequestService.dart';
import '../../models/Request.dart';

class StaffDashboardPage extends StatefulWidget {
  final String role;

  final String? departmentId;

  final String staffUserId;

  const StaffDashboardPage({
    super.key,
    required this.role,
    required this.staffUserId,
    this.departmentId,
  });

  @override
  State<StaffDashboardPage> createState() =>
      _StaffDashboardPageState();
}

class _StaffDashboardPageState
    extends State<StaffDashboardPage> {
  final RequestService _requestService =
      RequestService();

  bool _isLoading = true;

  String? _error;

  int _total = 0;
  int _pending = 0;
  int _approved = 0;
  int _resolved = 0;
  int _rejected = 0;
  int _forwarding = 0;

  List<Request> _recentRequests = [];

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadDashboard() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data =
          await _requestService.getStaffDashboard(
        role: widget.role,
        departmentId:
            widget.departmentId,
      );

      if (!mounted) return;

      setState(() {
        _total = data['total'] ?? 0;
        _pending = data['pending'] ?? 0;
        _approved = data['approved'] ?? 0;
        _resolved = data['resolved'] ?? 0;
        _rejected = data['rejected'] ?? 0;
        _forwarding =
            data['forwarding'] ?? 0;

        _recentRequests =
            List<Request>.from(
          data['recentRequests'] ?? [],
        );

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // OPEN LIST
  // ============================================================

  void _openStaffList({
    String? status,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffListPage(
          role: widget.role,
          departmentId:
              widget.departmentId,
          initialStatus: status,
          staffUserId:
              widget.staffUserId,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _statusText(String? status) {
    switch (status) {
      case 'PENDING':
        return 'Đang chờ';

      case 'APPROVED':
        return 'Đã duyệt';

      case 'RESOLVED':
        return 'Đã xử lý';

      case 'REJECTED':
        return 'Từ chối';

      case 'FORWARDING':
        return 'Đang chuyển';

      default:
        return status ??
            'Không xác định';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;

      case 'APPROVED':
        return Colors.blue;

      case 'RESOLVED':
        return Colors.green;

      case 'REJECTED':
        return Colors.red;

      case 'FORWARDING':
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'PENDING':
        return Icons.pending_actions;

      case 'APPROVED':
        return Icons.check_circle_outline;

      case 'RESOLVED':
        return Icons.task_alt;

      case 'REJECTED':
        return Icons.cancel_outlined;

      case 'FORWARDING':
        return Icons.forward;

      default:
        return Icons.help_outline;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text(
          'Dashboard Staff',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor:
            Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed:
                _loadDashboard,
            icon:
                const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),

              const SizedBox(height: 12),

              const Text(
                'Không thể tải dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed:
                    _loadDashboard,
                icon:
                    const Icon(Icons.refresh),
                label:
                    const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),

          const SizedBox(height: 20),

          const Text(
            'Tổng quan',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _buildStatistics(),

          const SizedBox(height: 24),

          _buildRecentRequests(),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeCard() {
    final isAdmin =
        widget.role.toUpperCase() ==
            'ROLE_ADMIN';

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF3949AB),
            Color(0xFF5C6BC0),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.18),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xin chào Staff 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  isAdmin
                      ? 'Bạn đang quản lý tất cả góp ý.'
                      : 'Bạn đang quản lý góp ý của đơn vị.',
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _buildStatisticCard(
          title: 'Tổng góp ý',
          value: _total,
          icon:
              Icons.inbox_outlined,
          color: Colors.indigo,
          onTap:
              () => _openStaffList(),
        ),

        _buildStatisticCard(
          title: 'Đang chờ',
          value: _pending,
          icon:
              Icons.pending_actions,
          color: Colors.orange,
          onTap: () =>
              _openStaffList(
            status: 'PENDING',
          ),
        ),

        _buildStatisticCard(
          title: 'Đã duyệt',
          value: _approved,
          icon:
              Icons.check_circle_outline,
          color: Colors.blue,
          onTap: () =>
              _openStaffList(
            status: 'APPROVED',
          ),
        ),

        _buildStatisticCard(
          title: 'Đã xử lý',
          value: _resolved,
          icon: Icons.task_alt,
          color: Colors.green,
          onTap: () =>
              _openStaffList(
            status: 'RESOLVED',
          ),
        ),

        _buildStatisticCard(
          title: 'Từ chối',
          value: _rejected,
          icon:
              Icons.cancel_outlined,
          color: Colors.red,
          onTap: () =>
              _openStaffList(
            status: 'REJECTED',
          ),
        ),

        _buildStatisticCard(
          title: 'Đang chuyển',
          value: _forwarding,
          icon: Icons.forward,
          color: Colors.purple,
          onTap: () =>
              _openStaffList(
            status: 'FORWARDING',
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(
                  0.1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 25,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                      color: color,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors
                          .grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RECENT
  // ============================================================

  Widget _buildRecentRequests() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Góp ý gần đây',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (_recentRequests.isEmpty)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 50,
                  color: Colors.grey,
                ),

                SizedBox(height: 10),

                Text(
                  'Chưa có góp ý.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
        else
          ..._recentRequests.map(
            (request) {
              final color =
                  _statusColor(
                request.currentStatus,
              );

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        color.withOpacity(
                      0.12,
                    ),
                    child: Icon(
                      _statusIcon(
                        request.currentStatus,
                      ),
                      color: color,
                    ),
                  ),

                  title: Text(
                    request.subject ??
                        'Không có tiêu đề',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),

                  subtitle: Text(
                    _statusText(
                      request.currentStatus,
                    ),
                  ),

                  trailing:
                      const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 15,
                  ),

                  onTap: () {
                    _openStaffList(
                      status:
                          request
                              .currentStatus,
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}