// lib/widgets/reaction_button.dart
// Nút "Thích" kiểu Facebook: chạm = thích / bỏ thích, nhấn giữ = mở thanh 6 reaction.
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'forum_utils.dart';

class ReactionButton extends StatefulWidget {
  /// Reaction hiện tại của người dùng (null nếu chưa thả)
  final String? current;

  /// Gọi với loại reaction được chọn. Service sẽ tự toggle (cùng loại = bỏ).
  final ValueChanged<String> onReact;

  /// compact = chỉ chữ nhỏ (dùng cho bình luận)
  final bool compact;

  const ReactionButton({
    super.key,
    required this.current,
    required this.onReact,
    this.compact = false,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hide),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -6),
          child: Material(
            color: Colors.white,
            elevation: 8,
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: kReactionTypes
                    .map((t) => GestureDetector(
                          onTap: () {
                            _hide();
                            widget.onReact(t);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(kReactionEmoji[t]!, style: const TextStyle(fontSize: 30)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.current?.toUpperCase();
    final color = reactionColor(cur);
    final label = cur == null ? 'Thích' : (kReactionLabels[cur] ?? 'Thích');

    final Widget content = widget.compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              cur == null
                  ? const Icon(Icons.thumb_up_alt_outlined, size: 20, color: kFbText2)
                  : Text(kReactionEmoji[cur] ?? '👍', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ]),
          );

    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        onTap: () => widget.onReact(cur ?? 'LIKE'),
        onLongPress: _show,
        child: content,
      ),
    );
  }
}