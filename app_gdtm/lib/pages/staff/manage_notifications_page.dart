// lib/pages/staff/manage_notifications_page.dart
// Quản lý thông báo (giảng viên): đăng thông báo mới kèm tệp pdf / word / excel
// và xem lại các thông báo đã đăng.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/pages/common/announcement_detail_page.dart';
import 'package:app_gdtm/services/RequestService.dart';
import 'package:app_gdtm/services/announcement_service.dart';
import 'package:app_gdtm/widgets/announcement_card.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/page_title.dart';

class ManageNotificationsPage extends StatefulWidget {
  final AnnouncementService service;

  const ManageNotificationsPage({super.key, required this.service});

  @override
  State<ManageNotificationsPage> createState() => _ManageNotificationsPageState();
}

class _ManageNotificationsPageState extends State<ManageNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final List<PlatformFile> _files = [];

  late Future<List<AnnouncementItem>> _listFuture = widget.service.getMyAnnouncements();

  bool _submitting = false;
  String? _progressText;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ---------------- Tệp đính kèm ----------------

  int get _totalBytes => _files.fold<int>(0, (sum, f) => sum + f.size);

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // cần bytes để upload (Web + mobile)
      type: FileType.custom,
      allowedExtensions: AnnouncementService.allowedExtensions,
    );
    if (result == null) return;

    final problems = <String>[];
    setState(() {
      for (final f in result.files) {
        if (_files.any((e) => e.name == f.name && e.size == f.size)) continue;
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

  // ---------------- Đăng / làm mới ----------------

  void _reset() {
    _formKey.currentState?.reset();
    _titleCtrl.clear();
    _contentCtrl.clear();
    setState(() {
      _files.clear();
      _error = null;
      _progressText = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _progressText = _files.isEmpty ? 'Đang đăng thông báo...' : null;
    });

    try {
      await widget.service.createAnnouncement(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        files: List.of(_files),
        onUploadProgress: (done, total) {
          if (!mounted || total == 0) return;
          setState(() {
            _progressText = done < total
                ? 'Đang tải tệp ${done + 1}/$total lên Cloudinary...'
                : 'Đang lưu thông báo...';
          });
        },
      );

      if (!mounted) return;
      _reset();
      setState(() {
        _listFuture = widget.service.getMyAnnouncements();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng thông báo thành công!')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressText = null;
        });
      }
    }
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Vui lòng điền thông tin này.' : null;

  static InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black26),
        ),
      );

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth >= 700 ? 32.0 : 14.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const PageTitle('QUẢN LÝ THÔNG BÁO'),
          const SizedBox(height: 16),
          _buildFormPanel(),
          const SizedBox(height: 24),
          const Text('Thông báo đã đăng',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          _buildMyList(),
        ]),
      );
    });
  }

  Widget _buildFormPanel() {
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
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.campaign_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Đăng thông báo mới',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ]),
          const Divider(height: 24),
          if (_error != null) _alert(_error!),
          _label('Tiêu đề', required: true),
          TextFormField(
            controller: _titleCtrl,
            enabled: !_submitting,
            maxLength: 200,
            decoration: _decoration('Tiêu đề thông báo'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 8),
          _label('Nội dung', required: true),
          TextFormField(
            controller: _contentCtrl,
            enabled: !_submitting,
            minLines: 6,
            maxLines: 12,
            decoration: _decoration('Nội dung thông báo...'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 16),
          _label('Tệp đính kèm (PDF, Word, Excel)'),
          _buildUploadBox(),
          const SizedBox(height: 16),
          if (_submitting && _progressText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_progressText!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.primary)),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: _submitting ? null : _reset,
              child: const Text('Làm mới'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Đăng thông báo'),
            ),
          ]),
        ]),
      ),
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
      child: Column(children: [
        const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.primary),
        const SizedBox(height: 6),
        const Text('Chọn tệp .pdf, .doc, .docx, .xls, .xlsx',
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        const Text('Tối đa 20MB mỗi tệp, tổng 40MB',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickFiles,
          icon: const Icon(Icons.attach_file),
          label: const Text('Chọn tệp'),
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < _files.length; i++) _fileRow(i),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Tổng: ${formatFileSize(_totalBytes)} / 40 MB',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ],
      ]),
    );
  }

  Widget _fileRow(int i) {
    final f = _files[i];
    final dot = f.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
    final kind = ext == 'pdf'
        ? AttachmentKind.pdf
        : (ext == 'doc' || ext == 'docx')
            ? AttachmentKind.word
            : (ext == 'xls' || ext == 'xlsx')
                ? AttachmentKind.excel
                : AttachmentKind.other;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(children: [
        Icon(kindIcon(kind), size: 20, color: kindColor(kind)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${f.name} (${formatFileSize(f.size)})',
              overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          tooltip: 'Bỏ tệp',
          icon: const Icon(Icons.close, size: 18),
          onPressed: _submitting ? null : () => setState(() => _files.removeAt(i)),
        ),
      ]),
    );
  }

  Widget _buildMyList() {
    return FutureBuilder<List<AnnouncementItem>>(
      future: _listFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Column(children: [
            Text(snap.error.toString(), style: const TextStyle(color: Colors.red)),
            TextButton(
              onPressed: () => setState(() {
                _listFuture = widget.service.getMyAnnouncements();
              }),
              child: const Text('Thử lại'),
            ),
          ]);
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Bạn chưa đăng thông báo nào',
                  style: TextStyle(color: Colors.black54)),
            ),
          );
        }
        return Column(children: [
          for (final item in items)
            AnnouncementCard(
              item: item,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnnouncementDetailPage(item: item)),
              ),
            ),
        ]);
      },
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        )),
      );

  Widget _alert(String message) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF5C2C0)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFB3261E))),
          ),
        ]),
      );
}