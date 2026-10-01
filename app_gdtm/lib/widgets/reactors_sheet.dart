// lib/widgets/reactors_sheet.dart
// Bottom sheet "ai đã thả reaction" kiểu Facebook: tab Tất cả + từng loại reaction.
import 'package:flutter/material.dart';
import 'package:app_gdtm/models/forum_post.dart';
import 'forum_utils.dart';

Future<void> showReactorsSheet(
  BuildContext context,
  Future<List<ReactorDTO>> Function() loader,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReactorsSheet(loader: loader),
  );
}

class _ReactorsSheet extends StatefulWidget {
  final Future<List<ReactorDTO>> Function() loader;
  const _ReactorsSheet({required this.loader});

  @override
  State<_ReactorsSheet> createState() => _ReactorsSheetState();
}

class _ReactorsSheetState extends State<_ReactorsSheet> {
  late final Future<List<ReactorDTO>> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: FutureBuilder<List<ReactorDTO>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final all = snap.data ?? [];
          if (all.isEmpty) {
            return const Center(
              child: Text('Chưa có ai thả reaction', style: TextStyle(color: kFbText2)),
            );
          }

          final byType = <String, List<ReactorDTO>>{};
          for (final r in all) {
            byType.putIfAbsent(r.type, () => []).add(r);
          }
          final types = kReactionTypes.where(byType.containsKey).toList();

          return DefaultTabController(
            length: types.length + 1,
            child: Column(children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TabBar(
                isScrollable: true,
                labelColor: kFbBlue,
                unselectedLabelColor: kFbText2,
                indicatorColor: kFbBlue,
                tabs: [
                  Tab(text: 'Tất cả ${all.length}'),
                  for (final t in types)
                    Tab(text: '${kReactionEmoji[t]} ${byType[t]!.length}'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _list(all),
                  for (final t in types) _list(byType[t]!),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _list(List<ReactorDTO> items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final r = items[i];
          return ListTile(
            leading: InitialAvatar(name: r.userName, radius: 20),
            title: Row(children: [
              Flexible(
                child: Text(
                  r.userName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: r.isAdmin
                        ? const Color(0xFFD32F2F)
                        : (r.isTeacher ? kFbBlue : null),
                  ),
                ),
              ),
              if (r.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: r.isAdmin ? const Color(0xFFD32F2F) : kFbBlue,
                ),
              ],
            ]),
            subtitle: r.date == null
                ? null
                : Text(timeAgo(r.date), style: const TextStyle(fontSize: 12)),
            trailing: Text(kReactionEmoji[r.type] ?? '👍',
                style: const TextStyle(fontSize: 22)),
          );
        },
      );
}