import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/RequestStatusHistory.dart';
import 'package:app_gdtm/models/ClarificationConversation.dart';
import 'package:app_gdtm/models/Message.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/pages/staff/staff_conversation_dialog.dart';
import 'package:app_gdtm/widgets/pdf_view_page.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/image_view_page.dart';
import 'package:app_gdtm/widgets/pdf_view.dart';

class FeedbackDetailPage extends StatefulWidget {
  final Request request;
  final String role;

  /// ID phòng ban của Staff hiện tại.
  final String? departmentId;

  /// Danh sách phòng ban dùng cho chức năng chuyển góp ý.
  final List<Department> departments;

  /// ID tài khoản Staff hiện tại.
  final String staffUserId;

  const FeedbackDetailPage({
    super.key,
    required this.request,
    required this.role,
    required this.staffUserId,
    this.departmentId,
    this.departments = const [],
  });

  @override
  State<FeedbackDetailPage> createState() =>
      _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final RequestService _requestService = RequestService();

  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isForwarding = false;

  late Request _request;

  FeedbackDetails _details = const FeedbackDetails();

  String? _selectedStatus;
  String? _selectedDepartmentId;

  final TextEditingController _forwardNoteController =
      TextEditingController();

  String? _senderFullName;

  final Map<String, String> _categoryNamesById = {};

  List<_DepartmentOption> _forwardDepartments = [];

  // ============================================================
  // QUYỀN THAO TÁC
  // ============================================================

  /// Chỉ Staff thuộc phòng ban đang sở hữu request mới được thao tác.
  ///
  /// Ví dụ:
  ///
  /// Staff CNTT:
  /// departmentId = DEP_CNTT
  ///
  /// Request:
  /// departmentId = DEP_CNTT
  ///
  /// => được thao tác.
  ///
  /// Sau khi chuyển:
  ///
  /// Request:
  /// departmentId = DEP_DAOTAO
  ///
  /// Staff CNTT:
  /// departmentId = DEP_CNTT
  ///
  /// => bị khóa.
  bool get _canOperateRequest {
    final requestDepartmentId = _request.departmentId?.trim();

    final staffDepartmentId = widget.departmentId?.trim();

    // Nếu chưa xác định được phòng ban của Staff
    // thì không cho thao tác để tránh thao tác nhầm.
    if (staffDepartmentId == null || staffDepartmentId.isEmpty) {
      return false;
    }

    if (requestDepartmentId == null || requestDepartmentId.isEmpty) {
      return false;
    }

    return requestDepartmentId == staffDepartmentId;
  }

  @override
  void initState() {
    super.initState();

    _request = widget.request;

    _loadDetails();
  }

  @override
  void dispose() {
    _forwardNoteController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD DETAIL
  // ============================================================

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _requestService.getFeedbackDetails(_request),
        _loadSenderName(),
        _loadCategoryNames(),
        _loadDepartments(),
      ]);

      final details = results[0] as FeedbackDetails;

      if (!mounted) return;

      setState(() {
        _details = details;
        _selectedStatus = null;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Không thể tải chi tiết góp ý: $e', isError: true);
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // LOAD SENDER
  // ============================================================

  Future<String?> _loadSenderName() async {
    final userId = _request.userId?.trim();

    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final direct = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (direct.exists) {
        final data = direct.data() ?? <String, dynamic>{};

        final name =
            (data['fullName'] ?? data['fullname'] ?? data['name'] ?? '')
                .toString()
                .trim();

        if (name.isNotEmpty) {
          _senderFullName = name;
          return name;
        }
      }

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        final name =
            (data['fullName'] ?? data['fullname'] ?? data['name'] ?? '')
                .toString()
                .trim();

        if (name.isNotEmpty) {
          _senderFullName = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('LOAD SENDER ERROR: $e');
    }

    return null;
  }

  // ============================================================
  // LOAD CATEGORY
  // ============================================================

  Future<void> _loadCategoryNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .get();

      _categoryNamesById.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final id = (data['id'] ?? doc.id).toString().trim();

        final name = (data['subject'] ?? data['name'] ?? data['title'] ?? '')
            .toString()
            .trim();

        if (id.isNotEmpty && name.isNotEmpty) {
          _categoryNamesById[id] = name;
        }
      }
    } catch (e) {
      debugPrint('LOAD CATEGORY ERROR: $e');
    }
  }

  // ============================================================
  // LOAD DEPARTMENTS
  // ============================================================

  Future<void> _loadDepartments() async {
    try {
      debugPrint('========== LOAD DEPARTMENTS ==========');

      debugPrint(
        'widget.departments.length = '
        '${widget.departments.length}',
      );

      // ========================================================
      // 1. Nếu đã truyền departments từ màn hình trước
      // ========================================================

      if (widget.departments.isNotEmpty) {
        _forwardDepartments = widget.departments
            .where((d) => d.id != null && d.id!.trim().isNotEmpty)
            .map(
              (d) => _DepartmentOption(d.id!.trim(), (d.name ?? d.id!).trim()),
            )
            .toList();

        debugPrint(
          'Lấy phòng ban từ widget: '
          '${_forwardDepartments.length}',
        );

        for (final department in _forwardDepartments) {
          debugPrint(
            'DEPARTMENT: '
            '${department.id} - '
            '${department.name}',
          );
        }

        debugPrint('======================================');

        return;
      }

      // ========================================================
      // 2. Không có dữ liệu từ widget
      //    => lấy Firestore
      //
      // Collection chính xác là:
      // department
      // ========================================================

      debugPrint(
        'widget.departments rỗng '
        '-> đang lấy Firestore...',
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('department')
          .get();

      debugPrint(
        'Firestore department docs = '
        '${snapshot.docs.length}',
      );

      final result = <_DepartmentOption>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        debugPrint('DOCUMENT ID = ${doc.id}');

        debugPrint('DATA = $data');

        final id = (data['id'] ?? doc.id).toString().trim();

        final name =
            (data['name'] ?? data['departmentName'] ?? data['title'] ?? id)
                .toString()
                .trim();

        if (id.isNotEmpty) {
          result.add(_DepartmentOption(id, name.isEmpty ? id : name));
        }
      }

      _forwardDepartments = result;

      debugPrint(
        'FINAL departments = '
        '${_forwardDepartments.length}',
      );

      for (final department in _forwardDepartments) {
        debugPrint(
          'FINAL: '
          '${department.id} - '
          '${department.name}',
        );
      }

      debugPrint('======================================');
    } catch (e, stackTrace) {
      debugPrint('❌ LOAD DEPARTMENTS ERROR: $e');

      debugPrint(stackTrace.toString());

      _forwardDepartments = [];
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> _updateStatus() async {
    if (!_canOperateRequest) {
      _showMessage(
        'Phòng ban hiện tại không có quyền xử lý góp ý này.',
        isError: true,
      );

      return;
    }

    final newStatus = _selectedStatus;

    if (newStatus == null || newStatus.isEmpty) {
      _showMessage('Vui lòng chọn trạng thái mới.');

      return;
    }

    final requestId = _request.id;

    if (requestId == null || requestId.isEmpty) {
      _showMessage('Góp ý không hợp lệ.', isError: true);

      return;
    }

    if (newStatus == _request.currentStatus) {
      _showMessage('Trạng thái mới giống trạng thái hiện tại.');

      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _requestService.updateStaffStatus(
        requestId: requestId,
        newStatus: newStatus,
        staffUserId: widget.staffUserId,
      );

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus(_request, newStatus);

        _selectedStatus = null;
      });

      await _loadDetails();

      if (!mounted) return;

      _showMessage(
        'Đã cập nhật trạng thái thành '
        '${_statusLabel(newStatus)}.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Không thể cập nhật trạng thái: $e', isError: true);
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  // ============================================================
  // FORWARD REQUEST
  // ============================================================

  Future<void> _forwardRequest() async {
    if (!_canOperateRequest) {
      _showMessage(
        'Phòng ban hiện tại không còn quyền chuyển góp ý này.',
        isError: true,
      );

      return;
    }

    final requestId = _request.id;

    if (requestId == null || requestId.isEmpty) {
      _showMessage('Góp ý không hợp lệ.', isError: true);

      return;
    }

    final toDepartmentId = _selectedDepartmentId;

    if (toDepartmentId == null || toDepartmentId.isEmpty) {
      _showMessage('Vui lòng chọn phòng ban cần chuyển đến.');

      return;
    }

    if (toDepartmentId == _request.departmentId) {
      _showMessage(
        'Không thể chuyển đến cùng phòng ban hiện tại.',
        isError: true,
      );

      return;
    }

    setState(() {
      _isForwarding = true;
    });

    try {
      await _requestService.forwardRequest(
        requestId: requestId,
        toDepartmentId: toDepartmentId,
        staffUserId: widget.staffUserId,
        note: _forwardNoteController.text.trim(),
      );

      if (!mounted) return;

      // Sau khi chuyển:
      //
      // departmentId = phòng ban mới
      // currentStatus = PENDING
      //
      // Nếu Staff hiện tại thuộc phòng ban cũ
      // => _canOperateRequest sẽ tự động = false.

      setState(() {
        _request = _copyRequestWithDepartment(_request, toDepartmentId);

        _selectedDepartmentId = null;

        _forwardNoteController.clear();

        _selectedStatus = null;
      });

      await _loadDetails();

      if (!mounted) return;

      _showMessage('Đã chuyển góp ý sang phòng ban mới.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Không thể chuyển góp ý: $e', isError: true);
    } finally {
      if (!mounted) return;

      setState(() {
        _isForwarding = false;
      });
    }
  }

  // ============================================================
  // COPY REQUEST
  // ============================================================

  Request _copyRequestWithStatus(Request request, String status) {
    return request.copyWith(currentStatus: status);
  }

  Request _copyRequestWithDepartment(Request request, String departmentId) {
    return request.copyWith(
      departmentId: departmentId,
      currentStatus: 'PENDING',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết góp ý'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadDetails,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBasicInformation(),

                  const SizedBox(height: 16),

                  _buildStatusSection(),

                  const SizedBox(height: 16),

                  _buildAttachmentsSection(),

                  const SizedBox(height: 16),

                  _buildHistorySection(),

                  const SizedBox(height: 16),

                  _buildConversationSection(),

                  const SizedBox(height: 16),

                  _buildForwardSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  Widget _buildBasicInformation() {
    final request = _request;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin góp ý',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildInfoRow(
              icon: Icons.subject,
              title: 'Tiêu đề',
              value: request.subject ?? 'Không có',
            ),

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.description_outlined,
              title: 'Nội dung',
              value: request.description ?? 'Không có',
            ),

            if (request.location != null &&
                request.location!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),

              _buildInfoRow(
                icon: Icons.location_on_outlined,
                title: 'Địa điểm',
                value: request.location!,
              ),
            ],

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.access_time,
              title: 'Thời gian gửi',
              value: _formatDate(request.timeCreate),
            ),

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.person_outline,
              title: 'Người gửi',
              value:
                  _senderFullName ??
                  request.user?.fullName ??
                  request.userId ??
                  'Không có',
            ),

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.category_outlined,
              title: 'Danh mục',
              value: _categoryNames(request),
            ),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.flag_outlined, size: 22),

                const SizedBox(width: 12),

                const Text(
                  'Trạng thái:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(width: 8),

                _buildStatusBadge(request.currentStatus ?? 'PENDING'),
              ],
            ),

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.business_outlined,
              title: 'Phòng ban xử lý',
              value: _departmentName(request.departmentId),
            ),

            // ==================================================
            // THÔNG BÁO KHÔNG CÒN QUYỀN
            // ==================================================
            if (!_canOperateRequest)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: .30),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Góp ý này hiện thuộc phòng ban khác. '
                        'Bạn không còn quyền thao tác.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
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
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade700),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 3),

              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS SECTION
  // ============================================================

  Widget _buildStatusSection() {
    final currentStatus = _request.currentStatus ?? 'PENDING';

    final statuses = _availableStatuses(currentStatus);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cập nhật trạng thái',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Trạng thái hiện tại: '
              '${_statusLabel(currentStatus)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // DROPDOWN
            // ==================================================
            DropdownButtonFormField<String>(
              value: _selectedStatus,

              decoration: InputDecoration(
                labelText: 'Trạng thái mới',
                border: const OutlineInputBorder(),
                enabled: _canOperateRequest && !_isUpdatingStatus,
                prefixIcon: const Icon(Icons.flag_outlined),
              ),

              items: statuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(_statusLabel(status)),
                );
              }).toList(),

              onChanged:
                  (!_canOperateRequest || _isUpdatingStatus || statuses.isEmpty)
                  ? null
                  : (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
            ),

            const SizedBox(height: 12),

            // ==================================================
            // UPDATE BUTTON
            // ==================================================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (!_canOperateRequest ||
                        _isUpdatingStatus ||
                        statuses.isEmpty)
                    ? null
                    : _updateStatus,

                icon: _isUpdatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _canOperateRequest ? Icons.save : Icons.lock_outline,
                      ),

                label: Text(
                  !_canOperateRequest
                      ? 'Không có quyền thao tác'
                      : statuses.isEmpty
                      ? 'Không có trạng thái để cập nhật'
                      : _isUpdatingStatus
                      ? 'Đang cập nhật...'
                      : 'Cập nhật trạng thái',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AVAILABLE STATUS
  // ============================================================

  List<String> _availableStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'PENDING':
        return ['APPROVED', 'REJECTED'];

      case 'APPROVED':
        return ['RESOLVED', 'REJECTED'];

      case 'RESOLVED':
      case 'REJECTED':
      case 'FORWARDING':
        return [];

      default:
        return [];
    }
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  Widget _buildAttachmentsSection() {
    final attachments = _details.attachments;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File đính kèm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (attachments.isEmpty)
              Text(
                'Không có file đính kèm.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...attachments.map(_buildAttachmentItem),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(FileAttachment attachment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _openAttachment(attachment),

        leading: const Icon(Icons.attach_file),

        title: Text(
          attachment.filename ?? 'File',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        subtitle: Text(_formatFileSize(attachment.filesize)),

        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Mở file',
          onPressed: () => _openAttachment(attachment),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS HISTORY
  // ============================================================

  Widget _buildHistorySection() {
    final histories = List<RequestStatusHistory>.from(_details.histories)
      ..sort((a, b) {
        final aTime = a.createAt;
        final bTime = b.createAt;

        if (aTime == null && bTime == null) {
          return 0;
        }

        if (aTime == null) {
          return 1;
        }

        if (bTime == null) {
          return -1;
        }

        return aTime.compareTo(bTime);
      });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch sử xử lý',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            if (histories.isEmpty)
              Text(
                'Chưa có lịch sử xử lý.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...histories.asMap().entries.map((entry) {
                final index = entry.key;

                final history = entry.value;

                return _buildHistoryItem(
                  history,
                  isLast: index == histories.length - 1,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    RequestStatusHistory history, {
    required bool isLast,
  }) {
    final status = history.status ?? 'UNKNOWN';

    final color = _statusColor(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(status), color: color, size: 17),
                ),

                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: color.withValues(alpha: .20),
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 13,
                        color: Colors.grey,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        _formatDate(history.createAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERSATION
  // ============================================================

  Future<void> _openMessages() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StaffConversationDialog(
        request: _request,
        staffUserId: widget.staffUserId,
        canOperate: _canOperateRequest,
      ),
    );

    // Làm mới để mục "Trao đổi" hiện đúng số cuộc trao đổi (có thể bỏ dòng này).
    if (mounted) await _loadDetails();
  }

  Widget _buildConversationSection() {
    final conversations = _details.conversations;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_outlined),
                SizedBox(width: 8),
                Text(
                  'Trao đổi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              conversations.isEmpty
                  ? 'Chưa có cuộc trao đổi nào.'
                  : 'Có ${conversations.length} '
                        'cuộc trao đổi.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMessages,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Mở hộp thoại chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(ClarificationConversation conversation) {
    final messages = conversation.messages ?? [];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,

      title: Text(
        conversation.subject ?? 'Trao đổi',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),

      subtitle: Text(conversation.isOpen == true ? 'Đang mở' : 'Đã đóng'),

      children: [
        if (messages.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Chưa có tin nhắn.'),
          )
        else
          ...messages.map(_buildMessageItem),
      ],
    );
  }

  Widget _buildMessageItem(Message message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.content ?? '', style: const TextStyle(fontSize: 14)),

          const SizedBox(height: 6),

          Text(
            _formatDate(message.createAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORWARD SECTION
  // ============================================================

  Widget _buildForwardSection() {
    final canForward =
        _request.currentStatus == 'APPROVED' && _canOperateRequest;

    final availableDepartments = _forwardDepartments
        .where((department) => department.id != _request.departmentId)
        .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forward_outlined),
                SizedBox(width: 8),
                Text(
                  'Chuyển phòng ban',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Phòng ban hiện tại: '
              '${_departmentName(_request.departmentId)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // KHÔNG CÓ PHÒNG BAN
            // ==================================================
            if (availableDepartments.isEmpty)
              Text(
                'Không có phòng ban khác để chuyển.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            // ==================================================
            // CÓ PHÒNG BAN
            // ==================================================
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!canForward || _isForwarding)
                      ? null
                      : _showForwardDialog,

                  icon: _isForwarding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _canOperateRequest
                              ? Icons.forward_outlined
                              : Icons.lock_outline,
                        ),

                  label: Text(
                    !_canOperateRequest
                        ? 'Phòng ban này không còn quyền xử lý'
                        : _request.currentStatus != 'APPROVED'
                        ? 'Chỉ có thể chuyển khi đang xử lý'
                        : _isForwarding
                        ? 'Đang chuyển...'
                        : 'Chuyển phòng ban',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORWARD DIALOG
  // ============================================================

  Future<void> _showForwardDialog() async {
    if (!_canOperateRequest) {
      _showMessage(
        'Phòng ban hiện tại không có quyền chuyển góp ý này.',
        isError: true,
      );

      return;
    }

    final available = _forwardDepartments
        .where((d) => d.id != _request.departmentId)
        .toList();

    if (available.isEmpty) {
      _showMessage('Chưa có phòng ban khác để chuyển tiếp.', isError: true);

      return;
    }

    String? selectedId;

    final noteController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.forward_outlined),
              SizedBox(width: 8),
              Text('Chuyển tiếp phản hồi'),
            ],
          ),

          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,

                  decoration: const InputDecoration(
                    labelText: 'Phòng ban nhận',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),

                  items: available.map((department) {
                    return DropdownMenuItem<String>(
                      value: department.id,
                      child: Text(department.name),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setDialogState(() {
                      selectedId = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  maxLines: 3,

                  decoration: const InputDecoration(
                    labelText: 'Ghi chú chuyển',
                    hintText: 'Nhập ghi chú nếu cần...',
                    border: OutlineInputBorder(),
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
                  : () => Navigator.pop(dialogContext, selectedId),

              icon: const Icon(Icons.forward_outlined),

              label: const Text('Chuyển tiếp'),
            ),
          ],
        ),
      ),
    );

    final selectedNote = noteController.text.trim();

    noteController.dispose();

    if (result == null) return;

    setState(() {
      _selectedDepartmentId = result;

      _forwardNoteController.text = selectedNote;
    });

    await _forwardRequest();
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  String _categoryNames(Request request) {
    final names = <String>[];

    for (final id in request.categoryIds) {
      final name = _categoryNamesById[id.trim()];

      if (name != null && name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
    }

    if (names.isEmpty) {
      for (final category in request.categories) {
        final name = category.subject.trim();

        if (name.isNotEmpty && !names.contains(name)) {
          names.add(name);
        }
      }
    }

    return names.isEmpty ? 'Không có' : names.join(', ');
  }

  // ============================================================
  // OPEN ATTACHMENT
  // ============================================================

  Future<void> _openAttachment(FileAttachment attachment) async {
  final url = attachment.fileUrl?.trim();

  if (url == null || url.isEmpty) {
    _showMessage(
      'Không tìm thấy đường dẫn tệp.',
      isError: true,
    );
    return;
  }

  final uri = Uri.tryParse(url);

  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    _showMessage(
      'Đường dẫn tệp không hợp lệ.',
      isError: true,
    );
    return;
  }

  final fileName = (attachment.filename ?? '').toLowerCase();

  // Lấy extension từ tên file hoặc URL
  final extension = fileName.contains('.')
      ? fileName.split('.').last
      : uri.path.toLowerCase().split('.').last;

  final isPdf = extension == 'pdf';

  final isImage = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  }.contains(extension);

  // ============================================================
  // PDF / ẢNH → HIỂN THỊ TRONG APP
  // ============================================================

  if (isPdf || isImage) {
    Widget preview;

    if (isPdf) {
      preview = PdfView(url: url);
    } else {
      preview = InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 50,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Không thể tải ảnh.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.96,
            height: MediaQuery.of(context).size.height * 0.92,
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    8,
                    10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf
                            : Icons.image_outlined,
                        color: const Color(0xFF005BAA),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          attachment.filename ?? 'Tệp đính kèm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),

                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                // ==================================================
                // FILE PREVIEW
                // ==================================================
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: isImage
                        ? Colors.black
                        : Colors.white,
                    child: preview,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return;
  }

  // ============================================================
  // WORD / EXCEL / FILE KHÁC
  // → MỞ ỨNG DỤNG BÊN NGOÀI
  // ============================================================

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _showMessage(
        'Không thể mở file.',
        isError: true,
      );
    }
  } catch (e) {
    if (!mounted) return;

    _showMessage(
      'Không thể mở file: $e',
      isError: true,
    );
  }
}

  // ============================================================
  // DEPARTMENT NAME
  // ============================================================

  String _departmentName(String? departmentId) {
    if (departmentId == null || departmentId.trim().isEmpty) {
      return 'Không xác định';
    }

    final id = departmentId.trim();

    // Tìm trong danh sách truyền từ widget
    for (final department in widget.departments) {
      if (department.id?.trim() == id) {
        final name = department.name?.trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }

        return id;
      }
    }

    // Tìm trong danh sách đã load
    // từ Firestore
    for (final department in _forwardDepartments) {
      if (department.id == id) {
        if (department.name.trim().isNotEmpty) {
          return department.name;
        }

        return id;
      }
    }

    return id;
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule_outlined;

      case 'APPROVED':
        return Icons.autorenew_rounded;

      case 'FORWARDING':
        return Icons.forward_outlined;

      case 'RESOLVED':
        return Icons.check_circle_outline;

      case 'REJECTED':
        return Icons.cancel_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Đang chờ tiếp nhận';

      case 'APPROVED':
        return 'Đang xử lý';

      case 'RESOLVED':
        return 'Đã xử lý';

      case 'REJECTED':
        return 'Từ chối';

      case 'FORWARDING':
        return 'Đã được chuyển tiếp';

      default:
        return status;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status) {
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

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Không rõ thời gian';
    }

    final value = date.toLocal();

    final day = value.day.toString().padLeft(2, '0');

    final month = value.month.toString().padLeft(2, '0');

    final year = value.year.toString();

    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year '
        '$hour:$minute';
  }
}

// ============================================================
// DEPARTMENT OPTION
// ============================================================

class _DepartmentOption {
  final String id;
  final String name;

  const _DepartmentOption(this.id, this.name);
}

// ============================================================
// CONVERSATION DIALOG
// ============================================================

class _ConversationDialog extends StatelessWidget {
  final List<ClarificationConversation> conversations;

  const _ConversationDialog({required this.conversations});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.forum_outlined),
          SizedBox(width: 8),
          Text('Trao đổi'),
        ],
      ),

      content: SizedBox(
        width: 650,
        child: conversations.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Chưa có cuộc trao đổi nào.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: conversations.length,

                separatorBuilder: (_, __) => const SizedBox(height: 8),

                itemBuilder: (context, index) {
                  final conversation = conversations[index];

                  final messages = conversation.messages ?? [];

                  return Card(
                    margin: EdgeInsets.zero,

                    child: ExpansionTile(
                      leading: Icon(
                        conversation.isOpen == true
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        color: conversation.isOpen == true
                            ? Colors.green
                            : Colors.grey,
                      ),

                      title: Text(
                        conversation.subject ?? 'Cuộc trao đổi',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      subtitle: Text(
                        conversation.isOpen == true ? 'Đang mở' : 'Đã đóng',
                      ),

                      children: messages.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Chưa có tin nhắn.'),
                              ),
                            ]
                          : messages.map((message) {
                              return ListTile(
                                leading: const Icon(Icons.message_outlined),

                                title: Text(message.content ?? ''),

                                subtitle: Text(
                                  _formatDateStatic(message.createAt),
                                ),
                              );
                            }).toList(),
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

  static String _formatDateStatic(DateTime? date) {
    if (date == null) {
      return 'Chưa cập nhật';
    }

    final value = date.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(value.day)}/'
        '${two(value.month)}/'
        '${value.year} '
        '${two(value.hour)}:'
        '${two(value.minute)}';
  }
}

// ============================================================
// FILE SIZE
// ============================================================

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return 'Không rõ dung lượng';
  }

  if (bytes < 1024) {
    return '$bytes B';
  }

  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
