import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/services/DepartmentService.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/page_title.dart';

class EditFeedbackPage extends StatefulWidget {
  final Users user;
  final Request request;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  const EditFeedbackPage({
    super.key,
    required this.user,
    required this.request,
    this.onSaved,
    this.onCancel,
  });

  @override
  State<EditFeedbackPage> createState() => _EditFeedbackPageState();
}

class _EditFeedbackPageState extends State<EditFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _service = RequestService();
  List<Category> _categories = [];
  List<Department> _departments = [];
  final List<PlatformFile> _files = [];
  List<FileAttachment> _existingFiles = [];
  final List<String> _selectedCategories = [];
  String? _departmentId;
  FeedbackPrivacy? _privacy;
  bool _loading = true;
  bool _saving = false;
  bool _loadingFiles = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject.text = widget.request.subject ?? '';
    _description.text = widget.request.description ?? '';
    _location.text = widget.request.location ?? '';
    _selectedCategories.addAll(widget.request.categoryIds);
    _departmentId = widget.request.departmentId;
    _privacy = widget.request.postStatus == RequestService.postStatusPublic
        ? FeedbackPrivacy.public
        : FeedbackPrivacy.department;
    _loadData();
    _loadExistingFiles();
  }

  Future<void> _loadExistingFiles() async {
    try {
      final details = await _service.getFeedbackDetails(widget.request);
      if (!mounted) return;
      setState(() {
        _existingFiles = details.attachments;
        _loadingFiles = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingFiles = false;
        _error = 'Không tải được tệp đính kèm: $error';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final result = await Future.wait([
        CategoryService().getActiveCategories(),
        DepartmentService().getDepartments(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = result[0] as List<Category>;
        _departments = (result[1] as List<Department>)
            .where((department) => department.isActive != false)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu: $error';
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final files = <PlatformFile>[];
    var total = 0;
    for (final file in result.files) {
      if (file.size > RequestService.maxFileBytes) {
        setState(() => _error = 'Mỗi tệp không được vượt quá 20MB.');
        return;
      }
      total += file.size;
      files.add(file);
    }
    if (total > RequestService.maxTotalBytes) {
      setState(() => _error = 'Tổng dung lượng tệp không được vượt quá 40MB.');
      return;
    }
    setState(() {
      _files
        ..clear()
        ..addAll(files);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving || _loadingFiles) return;
    final departmentId =
        _departmentId ?? RequestService.defaultDepartmentId(_departments);
    if (departmentId == null || _privacy == null) {
      setState(() => _error = 'Vui lòng chọn phòng ban và hình thức gửi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateFeedback(
        request: widget.request,
        userId: widget.user.id ?? '',
        subject: _subject.text,
        description: _description.text,
        location: _location.text,
        departmentId: departmentId,
        categoryIds: _selectedCategories,
        privacy: _privacy!,
        files: _files,
        retainedAttachmentIds: _existingFiles
            .map((file) => file.id)
            .whereType<String>()
            .toSet(),
      );
      if (!mounted) return;
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final padding = constraints.maxWidth >= 700 ? 32.0 : 14.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('CẬP NHẬT GÓP Ý'),
              const SizedBox(height: 16),
              if (_error != null) _AlertBox(message: _error!),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _detailPanel()),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _relatedPanel(),
                                  const SizedBox(height: 20),
                                  _privacyPanel(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _detailPanel(),
                        const SizedBox(height: 16),
                        _relatedPanel(),
                        const SizedBox(height: 16),
                        _privacyPanel(),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : widget.onCancel,
                            child: const Text('Hủy'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailPanel() {
    return _Panel(
      icon: Icons.description_outlined,
      title: 'Chi tiết góp ý',
      children: [
        const _FieldLabel('Tiêu đề góp ý', required: true),
        TextFormField(
          controller: _subject,
          enabled: !_saving,
          maxLength: 200,
          decoration: _inputDecoration('Mô tả ngắn gọn tiêu đề bạn muốn góp ý'),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 8),
        const _FieldLabel('Mô tả chi tiết', required: true),
        TextFormField(
          controller: _description,
          enabled: !_saving,
          minLines: 8,
          maxLines: 14,
          decoration: _inputDecoration('Nội dung góp ý chi tiết...'),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Địa điểm'),
        TextFormField(
          controller: _location,
          enabled: !_saving,
          decoration: _inputDecoration('Địa điểm liên quan (nếu có)'),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Tệp đính kèm'),
        _uploadBox(),
      ],
    );
  }

  Widget _relatedPanel() {
    return _Panel(
      icon: Icons.grid_view_outlined,
      title: 'Thông tin liên quan',
      children: [
        const _FieldLabel('Phòng ban', required: true),
        DropdownButtonFormField<String>(
          initialValue: _departmentId,
          isExpanded: true,
          menuMaxHeight: MediaQuery.sizeOf(context).height * .5,
          decoration: _inputDecoration('Chọn phòng ban'),
          items: _departments
              .where((item) => item.id != null)
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    item.name ?? 'Phòng ban',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _departmentId = value),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Danh mục'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories
              .where((item) => item.id != null)
              .map(
                (item) => FilterChip(
                  label: Text(item.subject),
                  selected: _selectedCategories.contains(item.id),
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            _selectedCategories.add(item.id!);
                          } else {
                            _selectedCategories.remove(item.id);
                          }
                        }),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _privacyPanel() {
    return _Panel(
      icon: Icons.public_outlined,
      title: 'Hình thức gửi',
      children: [
        DropdownButtonFormField<FeedbackPrivacy>(
          initialValue: _privacy,
          decoration: _inputDecoration('Chọn hình thức gửi'),
          items: const [
            DropdownMenuItem(
              value: FeedbackPrivacy.department,
              child: Text('Gửi đến phòng ban'),
            ),
            DropdownMenuItem(
              value: FeedbackPrivacy.public,
              child: Text('Đăng công khai diễn đàn'),
            ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _privacy = value),
        ),
      ],
    );
  }

  Widget _uploadBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: .4)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 36,
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          const Text('Quản lý tệp đính kèm'),
          const SizedBox(height: 2),
          const Text(
            'Bỏ tệp cũ hoặc thêm tệp mới',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (_loadingFiles)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_existingFiles.isNotEmpty)
            ..._existingFiles.map(
              (file) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.attach_file,
                  color: AppColors.primary,
                ),
                title: Text(
                  file.filename ?? 'Tệp đính kèm',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Tệp hiện tại'),
                trailing: IconButton(
                  tooltip: 'Bỏ tệp',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _existingFiles.remove(file)),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: const Text('Chọn tệp'),
          ),
          if (_files.isNotEmpty)
            ..._files.map(
              (file) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _files.remove(file)),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    );
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty ? 'Bắt buộc' : null;
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Panel({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        required ? '$text *' : text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AlertBox extends StatelessWidget {
  final String message;

  const _AlertBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}
