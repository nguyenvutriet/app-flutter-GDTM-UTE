import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/FileAttachment.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/services/CloudinaryService.dart';
import 'package:app_gdtm/services/conversation_chat_service.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_viewer_page.dart';

class StudentConversationDialog extends StatefulWidget {
  const StudentConversationDialog({
    super.key,
    required this.request,
    required this.studentId,
    this.initialConversationId,
  });

  final Request request;
  final String studentId;
  final String? initialConversationId;

  @override
  State<StudentConversationDialog> createState() =>
      _StudentConversationDialogState();
}

class _StudentConversationDialogState extends State<StudentConversationDialog> {
  final _service = ConversationChatService();
  String? _selectedId;
  late final Stream<List<ConversationInfo>> _conversations = _service
      .watchConversations(widget.request.id ?? '');

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialConversationId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height.clamp(300, 650) - 120,
        child: StreamBuilder<List<ConversationInfo>>(
          stream: _conversations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Không tải được cuộc trao đổi. Vui lòng thử lại.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text('Phòng ban chưa mở cuộc trao đổi cho góp ý này.'),
              );
            }
            final conversation = items.firstWhere(
              (item) => item.docId == _selectedId,
              orElse: () => items.first,
            );
            return Column(
              children: [
                if (items.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  item.subject.isEmpty
                                      ? 'Trao đổi'
                                      : item.subject,
                                ),
                                selected: item.docId == conversation.docId,
                                onSelected: (_) =>
                                    setState(() => _selectedId = item.docId),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (items.length > 1) const SizedBox(height: 8),
                Expanded(
                  child: _StudentConversation(
                    key: ValueKey(conversation.docId),
                    conversation: conversation,
                    studentId: widget.studentId,
                    service: _service,
                    requestId: widget.request.id ?? '',
                  ),
                ),
              ],
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

class _StudentConversation extends StatefulWidget {
  const _StudentConversation({
    super.key,
    required this.conversation,
    required this.studentId,
    required this.service,
    required this.requestId,
  });

  final ConversationInfo conversation;
  final String studentId;
  final ConversationChatService service;
  final String requestId;

  @override
  State<_StudentConversation> createState() => _StudentConversationState();
}

class _StudentConversationState extends State<_StudentConversation> {
  final _text = TextEditingController();
  final _files = <PlatformFile>[];
  late final Stream<List<ConversationMessage>> _messages = widget.service
      .watchMessages(widget.conversation);
  bool _sending = false;
  String? _error;
  final Map<String, String> _names = {};
  final Set<String> _requestedNames = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _resolveName(widget.studentId);
  }

  void _resolveName(String id) {
    if (id.trim().isEmpty || !_requestedNames.add(id)) return;
    widget.service.getUserName(id).then((name) {
      if (!mounted || name == null || name.isEmpty) return;
      setState(() => _names[id] = name);
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final selected = [..._files, ...result.files];
    final error = CloudinaryService.validateFiles(selected);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _files
        ..clear()
        ..addAll(selected);
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_text.text.trim().isEmpty && _files.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tin nhắn hoặc chọn tệp đính kèm.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final receiverId = await _receiverId();
      if (receiverId.isEmpty) {
        throw const ConversationChatException(
          'Không xác định được cán bộ nhận tin nhắn.',
        );
      }
      final uploads = await CloudinaryService().uploadFiles(
        _files,
        folder: CloudinaryConfig.conversationFolder,
        ownerId: widget.conversation.docId,
      );
      final attachments = uploads
          .map(
            (file) => FileAttachment(
              filename: file.fileName,
              fileUrl: file.secureUrl,
              filestype: file.fileType,
              filesize: file.bytes,
              publicId: file.publicId,
              resourceType: file.resourceType,
              deleteToken: file.deleteToken,
            ),
          )
          .toList();
      await widget.service.sendMessage(
        conversation: widget.conversation,
        senderId: widget.studentId,
        receiverId: receiverId,
        content: _text.text,
        attachments: attachments,
      );
      if (!mounted) return;
      setState(() {
        _text.clear();
        _files.clear();
      });
    } on ConversationChatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on CloudinaryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _receiverId() async {
    final snapshot = await widget.service
        .watchMessages(widget.conversation)
        .first;
    for (final message in snapshot) {
      if (message.senderId != widget.studentId &&
          message.receiverId.trim().isNotEmpty) {
        return message.senderId;
      }
      if (message.senderId == widget.studentId &&
          message.receiverId.trim().isNotEmpty) {
        return message.receiverId;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildConversationHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<ConversationMessage>>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Không tải được tin nhắn.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return const Center(child: Text('Chưa có tin nhắn.'));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final message = messages[messages.length - index - 1];
                  return _bubble(message);
                },
              );
            },
          ),
        ),
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ),
        if (_files.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              children: _files
                  .map(
                    (file) => Chip(
                      label: Text(file.name, overflow: TextOverflow.ellipsis),
                      onDeleted: _sending
                          ? null
                          : () => setState(() => _files.remove(file)),
                    ),
                  )
                  .toList(),
            ),
          ),
        Row(
          children: [
            IconButton(
              tooltip: 'Đính kèm tệp',
              onPressed: _sending || !widget.conversation.isOpen
                  ? null
                  : _pickFiles,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                enabled: !_sending && widget.conversation.isOpen,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending || !widget.conversation.isOpen ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Color(0xFF005BAA)),
            ),
          ],
        ),
        if (!widget.conversation.isOpen)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Cuộc trao đổi đã đóng, chỉ có thể xem lại.'),
          ),
      ],
    );
  }

  Widget _buildConversationHeader() {
    final subject = widget.conversation.subject.trim().isEmpty
        ? 'Cuộc hội thoại'
        : widget.conversation.subject.trim();
    final isOpen = widget.conversation.isOpen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EAF2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 19, color: Color(0xFF005BAA)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF172B4D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOpen ? 'Đang mở' : 'Đã đóng',
            style: TextStyle(
              color: isOpen ? const Color(0xFF16A34A) : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ConversationMessage message) {
    final mine = message.senderId == widget.studentId;
    if (!mine) _resolveName(message.senderId);
    final senderName = _names[message.senderId] ?? (mine ? 'Bạn' : 'Nhân viên');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 470),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFE6F0FB) : Colors.white,
          border: Border.all(color: const Color(0xFFE3EAF2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: const TextStyle(
                color: Color(0xFF172B4D),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (message.content.trim().isNotEmpty)
              SelectableText(message.content),
            ...message.attachments.map(_attachment),
            const SizedBox(height: 6),
            Text(
              _formatTime(message.createAt),
              style: const TextStyle(color: Colors.black54, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  Widget _attachment(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    final extension = attachmentExt(file);
    final isImage = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(extension);

    if (isImage && url.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tải được hình ảnh.'),
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 260,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fileLink(file),
            ),
          ),
        ),
      );
    }
    return _fileLink(file);
  }

  Widget _fileLink(FileAttachment file) {
    final url = file.fileUrl?.trim() ?? '';
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () {
              if (isPdf(file)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                      url: url,
                      title: file.filename ?? 'Tài liệu PDF',
                    ),
                  ),
                );
              } else {
                openUrl(context, url);
              }
            },
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kindIcon(attachmentKind(file)),
              size: 20,
              color: kindColor(attachmentKind(file)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                file.filename ?? 'Tệp đính kèm',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF005BAA),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
