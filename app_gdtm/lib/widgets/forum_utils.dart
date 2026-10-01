// lib/widgets/forum_utils.dart
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';

const Color kFbBlue = Color(0xFF1877F2);
const Color kFbBg = Color(0xFFF0F2F5);
const Color kFbText2 = Color(0xFF65676B);

const Map<String, String> kReactionLabels = {
  'LIKE': 'Thích',
  'LOVE': 'Yêu thích',
  'HAHA': 'Haha',
  'WOW': 'Wow',
  'SAD': 'Buồn',
  'ANGRY': 'Phẫn nộ',
};

/// Màu chữ của nút reaction giống Facebook.
Color reactionColor(String? type) {
  if (type == null) return kFbText2;
  switch (type.toUpperCase()) {
    case 'LIKE':
      return kFbBlue;
    case 'LOVE':
      return const Color(0xFFF33E58);
    case 'ANGRY':
      return const Color(0xFFE9710F);
    default:
      return const Color(0xFFF7B125);
  }
}

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
  if (diff.inHours < 24) return '${diff.inHours} giờ';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  return '${d.day}/${d.month}/${d.year}';
}

/// Top 3 emoji nhiều nhất từ map counts.
List<String> topReactionEmojis(Map<String, int> counts) {
  final e = counts.entries.where((x) => x.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return e.take(3).map((x) => kReactionEmoji[x.key.toUpperCase()] ?? '👍').toList();
}

class InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialAvatar({super.key, required this.name, this.radius = 20});

  static const _palette = [
    Color(0xFF1877F2),
    Color(0xFF42B72A),
    Color(0xFFF7B125),
    Color(0xFFE9710F),
    Color(0xFF8E44AD),
    Color(0xFF16A085),
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final last = words.isEmpty ? '' : words.last;
    final initial = last.isEmpty ? '?' : last.characters.first.toUpperCase();
    final color = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(initial,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.9)),
    );
  }
}

class ReactionSummary extends StatelessWidget {
  final List<String> emojis;
  final int total;

  const ReactionSummary({super.key, required this.emojis, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emojis.join(), style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Text('$total', style: const TextStyle(color: kFbText2, fontSize: 13)),
    ]);
  }
}