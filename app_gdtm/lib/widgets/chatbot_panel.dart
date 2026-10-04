// lib/widgets/chatbot_panel.dart
// Khung chat với trợ lý thông báo; mỗi câu trả lời kèm thẻ dẫn tới chi tiết thông báo.
import 'package:flutter/material.dart';

import 'package:app_gdtm/models/announcement_item.dart';
import 'package:app_gdtm/models/chat_message.dart';
import 'package:app_gdtm/pages/common/announcement_detail_page.dart';
import 'package:app_gdtm/services/chatbot_service.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/forum_utils.dart';

/// Mở khung chat dạng bottom sheet.
Future<void> showChatbotSheet(BuildContext context, ChatbotService service) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final available = media.size.height - media.viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: available * 0.92,
          child: ChatbotPanel(service: service, onClose: () => Navigator.pop(ctx)),
        ),
      );
    },
  );
}

class ChatbotPanel extends StatefulWidget {
  final ChatbotService service;
  final VoidCallback? onClose;

  const ChatbotPanel({super.key, required this.service, this.onClose});

  @override
  State<ChatbotPanel> createState() => _ChatbotPanelState();
}

class _ChatbotPanelState extends State<ChatbotPanel> {
  static const List<String> _suggestions = [
    'Có thông báo mới nhất nào?',
    'Lịch thi học kỳ này thế nào?',
    'Thông báo về học phí',
    'Thông báo nghỉ lễ, nghỉ học',
  ];

  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<ChatMessage> _messages = [
    const ChatMessage(
      isUser: false,
      isWelcome: true,
      text: 'Xin chào! Mình là trợ lý thông báo của trường. '
          'Bạn cần tìm thông tin nào? Mình sẽ tóm tắt và gửi để bạn mở xem chi tiết.',
    ),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _ctl.text).trim();
    if (q.isEmpty || _loading) return;
    _ctl.clear();

    final history = _messages.where((m) => !m.isWelcome && !m.isError).toList();
    setState(() {
      _messages.add(ChatMessage(isUser: true, text: q));
      _loading = true;
    });
    _scrollDown();

    try {
      final reply = await widget.service.ask(q, history: history);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(isUser: false, text: reply.text, cards: reply.cards));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(isUser: false, text: e.toString(), isError: true));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _openDetail(AnnouncementItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlyWelcome = _messages.length == 1;
    return Column(children: [
      // Tiêu đề
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Trợ lý thông báo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Hỏi đáp về thông báo chung của trường',
                  style: TextStyle(fontSize: 12, color: kFbText2)),
            ]),
          ),
          if (widget.onClose != null)
            IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
        ]),
      ),

      // Tin nhắn
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          children: [
            for (final m in _messages) _messageView(m),
            if (onlyWelcome) _suggestionChips(),
            if (_loading) _typing(),
          ],
        ),
      ),

      // Ô nhập
      const Divider(height: 1),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                enabled: !_loading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi về thông báo...',
                  filled: true,
                  fillColor: kFbBg,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: _loading ? Colors.black26 : kFbBlue),
              onPressed: _loading ? null : () => _send(),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _messageView(ChatMessage m) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: m.isUser
            ? kFbBlue
            : (m.isError ? const Color(0xFFFDECEA) : kFbBg),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        m.text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.35,
          color: m.isUser
              ? Colors.white
              : (m.isError ? const Color(0xFFB3261E) : Colors.black87),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          for (final item in m.cards)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _AnnouncementTile(item: item, onTap: () => _openDetail(item)),
            ),
        ],
      ),
    );
  }

  Widget _suggestionChips() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 13)),
                backgroundColor: const Color(0xFFE7F3FF),
                side: BorderSide.none,
                onPressed: () => _send(s),
              ),
          ],
        ),
      );

  Widget _typing() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Bạn đợi mình xíu nheeeee', style: TextStyle(color: kFbText2)),
        ]),
      );
}

/// Thẻ nhỏ dẫn tới chi tiết thông báo.
class _AnnouncementTile extends StatelessWidget {
  final AnnouncementItem item;
  final VoidCallback onTap;

  const _AnnouncementTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dept = item.department?.name;
    final meta = [
      if (dept != null && dept.isNotEmpty) dept,
      formatDateTime(item.date),
    ].where((e) => e.isNotEmpty).join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 44,
                color: const Color(0xFFE7F3FF),
                alignment: Alignment.center,
                child: const Icon(Icons.campaign_outlined, color: kFbBlue),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('THÔNG BÁO',
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 0.5, color: kFbText2)),
                      const SizedBox(height: 2),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: kFbText2)),
                      ],
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          for (final a in item.attachments.take(4))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(kindIcon(attachmentKind(a)),
                                  size: 16, color: kindColor(attachmentKind(a))),
                            ),
                          Text('${item.attachments.length} tệp',
                              style: const TextStyle(fontSize: 11.5, color: kFbText2)),
                        ]),
                      ],
                      const SizedBox(height: 4),
                      const Text('Xem chi tiết →',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kFbBlue)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}