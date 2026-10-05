import 'package:flutter/material.dart';



import 'package:app_gdtm/models/Department.dart';

import 'package:app_gdtm/models/FileAttachment.dart';

import 'package:app_gdtm/models/Request.dart';

import 'package:app_gdtm/models/RequestStatusHistory.dart';

import 'package:app_gdtm/models/ClarificationConversation.dart';

import 'package:app_gdtm/models/Message.dart';

import 'package:app_gdtm/services/RequestService.dart';



class FeedbackDetailPage extends StatefulWidget {

  final Request request;

  final String role;

  final String? departmentId;



  /// Danh sách phòng ban dùng cho chức năng chuyển góp ý.

  ///

  /// Nếu chưa có dữ liệu phòng ban thì truyền [].

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

  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();

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

    setState(() {

      _isLoading = true;

    });



    try {

      final details = await _requestService.getFeedbackDetails(_request);



      if (!mounted) return;



      setState(() {

        _details = details;

        _selectedStatus = null;

      });

    } catch (e) {

      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Không thể tải chi tiết góp ý: $e',

          ),

        ),

      );

    } finally {

      if (!mounted) return;



      setState(() {

        _isLoading = false;

      });

    }

  }



  // ============================================================

  // UPDATE STATUS

  // ============================================================



  Future<void> _updateStatus() async {

    final newStatus = _selectedStatus;



    if (newStatus == null || newStatus.isEmpty) {

      _showMessage('Vui lòng chọn trạng thái mới.');

      return;

    }



    final requestId = _request.id;



    if (requestId == null || requestId.isEmpty) {

      _showMessage('Góp ý không hợp lệ.');

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

        _request = _copyRequestWithStatus(

          _request,

          newStatus,

        );

        _selectedStatus = null;

      });



      await _loadDetails();



      if (!mounted) return;



      _showMessage(

        'Đã cập nhật trạng thái thành ${_statusLabel(newStatus)}.',

      );

    } catch (e) {

      if (!mounted) return;



      _showMessage(

        'Không thể cập nhật trạng thái: $e',

        isError: true,

      );

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

    final requestId = _request.id;



    if (requestId == null || requestId.isEmpty) {

      _showMessage('Góp ý không hợp lệ.');

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



      setState(() {

        _request = _copyRequestWithDepartment(

          _request,

          toDepartmentId,

        );



        _selectedDepartmentId = null;

        _forwardNoteController.clear();

      });



      await _loadDetails();



      if (!mounted) return;



      _showMessage('Đã chuyển góp ý sang phòng ban mới.');

    } catch (e) {

      if (!mounted) return;



      _showMessage(

        'Không thể chuyển góp ý: $e',

        isError: true,

      );

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



  Request _copyRequestWithStatus(

    Request request,

    String status,

  ) {

    return request.copyWith(

      currentStatus: status,

    );

  }



  Request _copyRequestWithDepartment(

    Request request,

    String departmentId,

  ) {

    return request.copyWith(

      departmentId: departmentId,

      currentStatus: 'PENDING',

    );

  }



  // ============================================================

  // MESSAGE

  // ============================================================



  void _showMessage(

    String message, {

    bool isError = false,

  }) {

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

          ? const Center(

              child: CircularProgressIndicator(),

            )

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

              style: TextStyle(

                fontSize: 20,

                fontWeight: FontWeight.bold,

              ),

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

              title: 'Mã sinh viên',

              value: request.userId ?? 'Không có',

            ),



            const SizedBox(height: 12),



            Row(

              crossAxisAlignment: CrossAxisAlignment.center,

              children: [

                const Icon(

                  Icons.flag_outlined,

                  size: 22,

                ),

                const SizedBox(width: 12),

                const Text(

                  'Trạng thái:',

                  style: TextStyle(

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(width: 8),

                _buildStatusBadge(

                  request.currentStatus ?? 'PENDING',

                ),

              ],

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

        Icon(

          icon,

          size: 22,

          color: Colors.grey.shade700,

        ),

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

              Text(

                value,

                style: const TextStyle(

                  fontSize: 15,

                ),

              ),

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

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 8),



            Text(

              'Trạng thái hiện tại: ${_statusLabel(currentStatus)}',

              style: TextStyle(

                color: Colors.grey.shade700,

              ),

            ),



            const SizedBox(height: 12),



            DropdownButtonFormField<String>(

              value: _selectedStatus,

              decoration: const InputDecoration(

                labelText: 'Trạng thái mới',

                border: OutlineInputBorder(),

              ),

              items: statuses.map((status) {

                return DropdownMenuItem<String>(

                  value: status,

                  child: Text(

                    _statusLabel(status),

                  ),

                );

              }).toList(),

              onChanged: _isUpdatingStatus

                  ? null

                  : (value) {

                      setState(() {

                        _selectedStatus = value;

                      });

                    },

            ),



            const SizedBox(height: 12),



            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                onPressed:

                    _isUpdatingStatus ? null : _updateStatus,

                icon: _isUpdatingStatus

                    ? const SizedBox(

                        width: 18,

                        height: 18,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                        ),

                      )

                    : const Icon(Icons.save),

                label: Text(

                  _isUpdatingStatus

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

        return [

          'APPROVED',

          'RESOLVED',

          'REJECTED',

        ];



      case 'APPROVED':

        return [

          'RESOLVED',

          'REJECTED',

          'FORWARDING',

        ];



      case 'RESOLVED':

      case 'REJECTED':

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

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 12),



            if (attachments.isEmpty)

              Text(

                'Không có file đính kèm.',

                style: TextStyle(

                  color: Colors.grey.shade600,

                ),

              )

            else

              ...attachments.map(

                _buildAttachmentItem,

              ),

          ],

        ),

      ),

    );

  }



  Widget _buildAttachmentItem(

    FileAttachment attachment,

  ) {

    return Card(

      margin: const EdgeInsets.only(bottom: 8),

      child: ListTile(

        leading: const Icon(

          Icons.attach_file,

        ),

        title: Text(

          attachment.filename ?? 'File',

          maxLines: 2,

          overflow: TextOverflow.ellipsis,

        ),

        subtitle: Text(

          _formatFileSize(attachment.filesize),

        ),

        trailing: IconButton(

          icon: const Icon(

            Icons.open_in_new,

          ),

          onPressed: () {

            final url = attachment.fileUrl;



            if (url == null || url.isEmpty) {

              _showMessage(

                'Không tìm thấy đường dẫn file.',

                isError: true,

              );

              return;

            }



            _showMessage(

              'File: $url',

            );

          },

        ),

      ),

    );

  }



  // ============================================================

  // STATUS HISTORY

  // ============================================================



  Widget _buildHistorySection() {

    final histories = _details.histories;



    return Card(

      elevation: 2,

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(

              'Lịch sử xử lý',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 16),



            if (histories.isEmpty)

              Text(

                'Chưa có lịch sử xử lý.',

                style: TextStyle(

                  color: Colors.grey.shade600,

                ),

              )

            else

              ...histories.asMap().entries.map(

                (entry) {

                  final index = entry.key;

                  final history = entry.value;



                  return _buildHistoryItem(

                    history,

                    isLast: index == histories.length - 1,

                  );

                },

              ),

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



    return Row(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Column(

          children: [

            Container(

              width: 14,

              height: 14,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: _statusColor(status),

              ),

            ),



            if (!isLast)

              Container(

                width: 2,

                height: 50,

                color: Colors.grey.shade300,

              ),

          ],

        ),



        const SizedBox(width: 12),



        Expanded(

          child: Padding(

            padding: const EdgeInsets.only(

              bottom: 16,

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  _statusLabel(status),

                  style: const TextStyle(

                    fontWeight: FontWeight.bold,

                  ),

                ),



                const SizedBox(height: 4),



                Text(

                  _formatDate(history.createAt),

                  style: TextStyle(

                    fontSize: 13,

                    color: Colors.grey.shade600,

                  ),

                ),

              ],

            ),

          ),

        ),

      ],

    );

  }



  // ============================================================

  // CONVERSATION

  // ============================================================



  Widget _buildConversationSection() {

    final conversations = _details.conversations;



    return Card(

      elevation: 2,

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(

              'Trao đổi',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 12),



            if (conversations.isEmpty)

              Text(

                'Chưa có cuộc trao đổi nào.',

                style: TextStyle(

                  color: Colors.grey.shade600,

                ),

              )

            else

              ...conversations.map(

                _buildConversationItem,

              ),

          ],

        ),

      ),

    );

  }



  Widget _buildConversationItem(

    ClarificationConversation conversation,

  ) {

    final messages = conversation.messages ?? [];



    return ExpansionTile(

      tilePadding: EdgeInsets.zero,

      title: Text(

        conversation.subject ?? 'Trao đổi',

        style: const TextStyle(

          fontWeight: FontWeight.w600,

        ),

      ),

      subtitle: Text(

        conversation.isOpen == true

            ? 'Đang mở'

            : 'Đã đóng',

      ),

      children: [

        if (messages.isEmpty)

          const Padding(

            padding: EdgeInsets.all(12),

            child: Text(

              'Chưa có tin nhắn.',

            ),

          )

        else

          ...messages.map(

            _buildMessageItem,

          ),

      ],

    );

  }



  Widget _buildMessageItem(

    Message message,

  ) {

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(

        bottom: 8,

      ),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(8),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            message.content ?? '',

            style: const TextStyle(

              fontSize: 14,

            ),

          ),



          const SizedBox(height: 6),



          Text(

            _formatDate(message.createAt),

            style: TextStyle(

              fontSize: 12,

              color: Colors.grey.shade600,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // FORWARD SECTION

  // ============================================================



  Widget _buildForwardSection() {

    final availableDepartments = widget.departments

        .where(

          (department) =>

              department.id != null &&

              department.id != _request.departmentId,

        )

        .toList();



    return Card(

      elevation: 2,

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(

              'Chuyển phòng ban',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 8),



            Text(

              'Phòng ban hiện tại: '

              '${_departmentName(_request.departmentId)}',

              style: TextStyle(

                color: Colors.grey.shade700,

              ),

            ),



            const SizedBox(height: 12),



            if (availableDepartments.isEmpty)

              Text(

                'Không có phòng ban khác để chuyển.',

                style: TextStyle(

                  color: Colors.grey.shade600,

                ),

              )

            else ...[

              DropdownButtonFormField<String>(

                value: _selectedDepartmentId,

                decoration: const InputDecoration(

                  labelText: 'Phòng ban nhận',

                  border: OutlineInputBorder(),

                ),

                items: availableDepartments.map(

                  (department) {

                    return DropdownMenuItem<String>(

                      value: department.id!,

                      child: Text(

                        department.name ?? department.id!,

                      ),

                    );

                  },

                ).toList(),

                onChanged: _isForwarding

                    ? null

                    : (value) {

                        setState(() {

                          _selectedDepartmentId = value;

                        });

                      },

              ),



              const SizedBox(height: 12),



              TextField(

                controller: _forwardNoteController,

                maxLines: 3,

                enabled: !_isForwarding,

                decoration: const InputDecoration(

                  labelText: 'Ghi chú chuyển',

                  hintText: 'Nhập ghi chú nếu cần...',

                  border: OutlineInputBorder(),

                ),

              ),



              const SizedBox(height: 12),



              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  onPressed:

                      _isForwarding ? null : _forwardRequest,

                  icon: _isForwarding

                      ? const SizedBox(

                          width: 18,

                          height: 18,

                          child: CircularProgressIndicator(

                            strokeWidth: 2,

                          ),

                        )

                      : const Icon(

                          Icons.forward,

                        ),

                  label: Text(

                    _isForwarding

                        ? 'Đang chuyển...'

                        : 'Chuyển phòng ban',

                  ),

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }



  // ============================================================

  // DEPARTMENT NAME

  // ============================================================



  String _departmentName(String? departmentId) {

    if (departmentId == null || departmentId.isEmpty) {

      return 'Không xác định';

    }



    for (final department in widget.departments) {

      if (department.id == departmentId) {

        return department.name ?? departmentId;

      }

    }



    return departmentId;

  }



  // ============================================================

  // STATUS BADGE

  // ============================================================



  Widget _buildStatusBadge(String status) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 10,

        vertical: 6,

      ),

      decoration: BoxDecoration(

        color: _statusColor(status).withValues(

          alpha: 0.12,

        ),

        borderRadius: BorderRadius.circular(20),

      ),

      child: Text(

        _statusLabel(status),

        style: TextStyle(

          color: _statusColor(status),

          fontSize: 12,

          fontWeight: FontWeight.bold,

        ),

      ),

    );

  }



  // ============================================================

  // STATUS LABEL

  // ============================================================



  String _statusLabel(String status) {

    switch (status) {

      case 'PENDING':

        return 'Chờ xử lý';



      case 'APPROVED':

        return 'Đã tiếp nhận';



      case 'RESOLVED':

        return 'Đã giải quyết';



      case 'REJECTED':

        return 'Từ chối';



      case 'FORWARDING':

        return 'Đang chuyển';



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



    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();



    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');



    return '$day/$month/$year $hour:$minute';

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

}