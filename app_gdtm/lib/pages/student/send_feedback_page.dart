import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/Category.dart';
import 'package:app_gdtm/models/Department.dart';
import 'package:app_gdtm/models/Users.dart';
import 'package:app_gdtm/services/CategoryService.dart';
import 'package:app_gdtm/services/DepartmentService.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/page_title.dart';

/// Trang "Gửi góp ý" của sinh viên.
/// Tệp đính kèm được upload lên Cloudinary, thông tin góp ý lưu Firestore.
class SendFeedbackPage extends StatefulWidget {
  final Users user;

  /// Gọi sau khi gửi thành công (vd: chuyển sang "Lịch sử góp ý").
  final VoidCallback? onSubmitted;

  const SendFeedbackPage({
    super.key,
    required this.user,
    this.onSubmitted,
  });

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  final _requestService = RequestService();

  List<Category> _categories = [];
  List<Department> _departments = [];
  bool _loadingData = true;
  String? _loadError;

  final List<Category> _selectedCategories = [];
  Department? _selectedDepartment;
  FeedbackPrivacy? _privacy;
  final List<PlatformFile> _files = [];

  bool _submitting = false;
  String? _progressText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // DỮ LIỆU
  // ============================================================

  Future<void> _loadData() async {
    setState(() {
      _loadingData = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        CategoryService().getActiveCategories(),
        DepartmentService().getDepartments(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _departments = (results[1] as List<Department>)
            .where((d) => d.isActive != false)
            .toList();
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Không tải được danh mục / phòng ban: $e';
        _loadingData = false;
      });
    }
  }

  // ============================================================
  // TỆP ĐÍNH KÈM
  // ============================================================

  int get _totalBytes => _files.fold<int>(0, (sum, f) => sum + f.size);

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // cần bytes để upload (Web + mobile)
    );
    if (result == null) return;

    final problems = <String>[];
    setState(() {
      for (final f in result.files) {
        final duplicated =
            _files.any((e) => e.name == f.name && e.size == f.size);
        if (duplicated) continue;

        if (f.size > RequestService.maxFileBytes) {
          problems.add('"${f.name}" vượt quá 20MB.');
          continue;
        }
        if (_totalBytes + f.size > RequestService.maxTotalBytes) {
          problems.add('Không thể thêm "${f.name}": tổng dung lượng vượt 40MB.');
          continue;
        }
        _files.add(f);
      }
      _error = problems.isEmpty ? null : problems.join('\n');
    });
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil().clamp(1, 1 << 30)} KB';
  }

  // ============================================================
  // GỬI / LÀM MỚI
  // ============================================================

  void _reset() {
    _formKey.currentState?.reset();
    _subjectCtrl.clear();
    _descriptionCtrl.clear();
    _locationCtrl.clear();
    setState(() {
      _selectedCategories.clear();
      _selectedDepartment = null;
      _privacy = null;
      _files.clear();
      _error = null;
      _progressText = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    final departmentId = _selectedDepartment?.id ??
        RequestService.defaultDepartmentId(_departments);
    if (departmentId == null) {
      setState(() => _error =
          'Không tìm thấy Phòng CTSV mặc định. Vui lòng chọn phòng ban.');
      return;
    }

    setState(() {
      _submitting = true;
      _progressText = _files.isEmpty ? 'Đang gửi góp ý...' : null;
    });

    try {
      await _requestService.submitFeedback(
        user: widget.user,
        subject: _subjectCtrl.text,
        description: _descriptionCtrl.text,
        location: _locationCtrl.text,
        departmentId: departmentId,
        categoryIds: _selectedCategories
            .map((c) => c.id)
            .whereType<String>()
            .toList(),
        privacy: _privacy!,
        files: List.of(_files),
        onUploadProgress: (done, total) {
          if (!mounted || total == 0) return;
          setState(() {
            _progressText = done < total
                ? 'Đang tải tệp ${done + 1}/$total lên Cloudinary...'
                : 'Đang lưu góp ý...';
          });
        },
      );

      if (!mounted) return;
      _reset();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Gửi góp ý thành công'),
          content: const Text(
            'Góp ý đã được gửi đến phòng ban. Bạn có thể theo dõi tiến độ trong lịch sử góp ý.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) widget.onSubmitted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressText = null;
        });
      }
    }
  }

  // ============================================================
  // GIAO DIỆN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final pad = c.maxWidth >= 700 ? 32.0 : 14.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Text(
              //   'TRƯỜNG ĐẠI HỌC CÔNG NGHỆ KỸ THUẬT TP.HCM',
              //   style: TextStyle(
              //     color: AppColors.primary,
              //     fontWeight: FontWeight.bold,
              //     fontSize: 14,
              //   ),
              // ),
              const SizedBox(height: 8),
              const PageTitle('GỬI GÓP Ý'),
              const SizedBox(height: 16),
              if (_error != null) _AlertBox(message: _error!),
              if (_loadError != null)
                _AlertBox(
                  message: _loadError!,
                  actionLabel: 'Thử lại',
                  onAction: _loadData,
                ),
              if (_loadingData)
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
                            Expanded(flex: 3, child: _buildDetailPanel()),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildRelatedPanel(),
                                  const SizedBox(height: 20),
                                  _buildPrivacyPanel(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildDetailPanel(),
                        const SizedBox(height: 16),
                        _buildRelatedPanel(),
                        const SizedBox(height: 16),
                        _buildPrivacyPanel(),
                      ],
                      const SizedBox(height: 20),
                      _buildActions(),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Panel: Chi tiết góp ý ----------------

  Widget _buildDetailPanel() {
    return _Panel(
      icon: Icons.description_outlined,
      title: 'Chi tiết góp ý',
      children: [
        const _FieldLabel('Tiêu đề góp ý', required: true),
        TextFormField(
          controller: _subjectCtrl,
          enabled: !_submitting,
          maxLength: 200,
          decoration: _inputDecoration(
            'Mô tả ngắn gọn tiêu đề bạn muốn góp ý',
          ),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 8),
        const _FieldLabel('Mô tả chi tiết', required: true),
        TextFormField(
          controller: _descriptionCtrl,
          enabled: !_submitting,
          minLines: 8,
          maxLines: 14,
          decoration: _inputDecoration('Nội dung góp ý chi tiết...'),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Tệp đính kèm'),
        _buildUploadBox(),
      ],
    );
  }

  Widget _buildUploadBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 36, color: AppColors.primary),
          const SizedBox(height: 6),
          const Text('Chọn tệp để tải lên'),
          const SizedBox(height: 2),
          const Text(
            'Tối đa 20MB mỗi tệp, tổng 40MB',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: const Text('Chọn tệp'),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _files.length; i++)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_files[i].name} (${_formatSize(_files[i].size)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bỏ tệp',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _files.removeAt(i)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tổng: ${_formatSize(_totalBytes)} / 40 MB',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Panel: Thông tin liên quan ----------------

  Widget _buildRelatedPanel() {
    final available = _categories
        .where((c) => !_selectedCategories.any((s) => s.id == c.id))
        .toList();

    return _Panel(
      icon: Icons.grid_view_outlined,
      title: 'Thông tin liên quan',
      children: [
        const _FieldLabel('Danh mục'),
        _PickerField<Category>(
          hint: available.isEmpty && _categories.isNotEmpty
              ? 'Đã chọn hết danh mục'
              : 'Chọn danh mục',
          items: available,
          labelOf: (c) => c.subject,
          enabled: !_submitting,
          onSelected: (c) => setState(() => _selectedCategories.add(c)),
        ),
        if (_selectedCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _selectedCategories)
                InputChip(
                  label: Text(c.subject),
                  onDeleted: _submitting
                      ? null
                      : () => setState(
                            () => _selectedCategories
                                .removeWhere((e) => e.id == c.id),
                          ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const _FieldLabel('Phòng ban'),
        _PickerField<Department>(
          hint: 'Để trống sẽ gửi mặc định đến Phòng CTSV',
          items: _departments,
          labelOf: (d) => d.name ?? '',
          selected: _selectedDepartment,
          enabled: !_submitting,
          onSelected: (d) => setState(() => _selectedDepartment = d),
          onCleared: () => setState(() => _selectedDepartment = null),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Địa điểm (nếu có)'),
        TextFormField(
          controller: _locationCtrl,
          enabled: !_submitting,
          decoration: _inputDecoration('VD: Tầng 2, Phòng A101'),
        ),
      ],
    );
  }

  // ---------------- Panel: Quyền riêng tư ----------------

  Widget _buildPrivacyPanel() {
    return _Panel(
      icon: Icons.lock_outline,
      title: 'Quyền riêng tư',
      children: [
        FormField<FeedbackPrivacy>(
          validator: (_) =>
              _privacy == null ? 'Vui lòng chọn một quyền riêng tư.' : null,
          builder: (field) {
            Widget option(
              FeedbackPrivacy value,
              String title,
              String subtitle,
            ) {
              final selected = _privacy == value;
              return InkWell(
                onTap: _submitting
                    ? null
                    : () {
                        setState(() => _privacy = value);
                        field.didChange(value);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? AppColors.primary : Colors.black38,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                option(
                  FeedbackPrivacy.department,
                  'Gửi đến phòng ban',
                  'Không đăng lên diễn đàn',
                ),
                const Divider(height: 1),
                option(
                  FeedbackPrivacy.public,
                  'Gửi công khai',
                  'Đăng lên diễn đàn',
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------- Nút hành động ----------------

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_submitting && _progressText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _progressText!,
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _submitting ? null : _reset,
              child: const Text('Làm mới'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gửi góp ý'),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------- Helpers ----------------

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Vui lòng điền thông tin này.' : null;

  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.black26),
      ),
    );
  }
}

// ================================================================
// WIDGET PHỤ
// ================================================================

/// Khung trắng có tiêu đề + icon (giống .panel bên bản web).
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
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
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
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
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ô chọn dạng combobox.
/// - Click vào toàn bộ ô để mở danh sách.
/// - Có ô tìm kiếm khi danh sách nhiều item.
/// - Hiển thị item đã chọn rõ ràng.
/// - Có nút xoá nếu truyền [onCleared].
class _PickerField<T> extends StatefulWidget {
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final T? selected;
  final bool enabled;
  final ValueChanged<T> onSelected;
  final VoidCallback? onCleared;

  const _PickerField({
    required this.hint,
    required this.items,
    required this.labelOf,
    required this.onSelected,
    this.selected,
    this.enabled = true,
    this.onCleared,
  });

  @override
  State<_PickerField<T>> createState() => _PickerFieldState<T>();
}

class _PickerFieldState<T> extends State<_PickerField<T>> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (!widget.enabled || widget.items.isEmpty) return;

    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _searchController.clear();

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Click ra ngoài để đóng
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox(),
              ),
            ),

            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: SizedBox(
                  width: _getFieldWidth(),
                  child: StatefulBuilder(
                    builder: (context, setOverlayState) {
                      final keyword =
                          _searchController.text.trim().toLowerCase();

                      final filteredItems = widget.items.where((item) {
                        final label = widget.labelOf(item).toLowerCase();
                        return label.contains(keyword);
                      }).toList();

                      return Container(
                        constraints: const BoxConstraints(
                          maxHeight: 320,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ô tìm kiếm
                            if (widget.items.length > 6)
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: (_) {
                                    setOverlayState(() {});
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF7F9FC),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.black12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.black12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (filteredItems.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Không tìm thấy dữ liệu',
                                    style: TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                    height: 1,
                                    color: Colors.black12,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    final isSelected =
                                        widget.selected == item;

                                    return InkWell(
                                      onTap: () {
                                        widget.onSelected(item);
                                        _removeOverlay();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        color: isSelected
                                            ? AppColors.primary
                                                .withOpacity(0.08)
                                            : Colors.white,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.labelOf(item),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);

    setState(() {
      _isOpen = true;
    });
  }

  double _getFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return 300;

    return renderBox.size.width;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (mounted && _isOpen) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.selected != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.enabled
                ? Colors.white
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isOpen
                  ? AppColors.primary
                  : Colors.black26,
              width: _isOpen ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue
                      ? widget.labelOf(widget.selected as T)
                      : widget.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasValue
                        ? Colors.black87
                        : Colors.black45,
                    fontWeight:
                        hasValue ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),

              // Nút xoá
              if (hasValue &&
                  widget.onCleared != null &&
                  widget.enabled)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    widget.onCleared!();
                    _removeOverlay();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black45,
                    ),
                  ),
                ),

              const SizedBox(width: 4),

              // Mũi tên dropdown
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: widget.enabled
                      ? Colors.black54
                      : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung thông báo lỗi (giống .form-alert bên bản web).
class _AlertBox extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AlertBox({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF5C2C0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
