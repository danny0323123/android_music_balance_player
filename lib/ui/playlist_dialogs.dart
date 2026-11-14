import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/library.dart';
import '../state/playlists.dart';
import 'common.dart';

/// 輸入播放清單名稱，取消時回傳 null。
Future<String?> askPlaylistName(
  BuildContext context, {
  String initial = '',
  required String title,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(
      initial: initial,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

/// 對話框自己持有輸入框的控制器，在元件真正移除時才釋放。
/// （若在 showDialog 回傳後就釋放，關閉動畫期間輸入框還在使用它，會觸發錯誤。）
class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.initial,
    required this.title,
    required this.confirmLabel,
  });

  final String initial;
  final String title;
  final String confirmLabel;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: context.l10n.playlistName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// 建立新播放清單，回傳新清單的 id。
Future<int?> createPlaylist(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final name = await askPlaylistName(
    context,
    title: l10n.newPlaylist,
    confirmLabel: l10n.create,
  );
  if (name == null) return null;
  return ref.read(databaseProvider).createPlaylist(name);
}

Future<void> renamePlaylist(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final l10n = context.l10n;
  final name = await askPlaylistName(
    context,
    initial: playlist.name,
    title: l10n.rename,
    confirmLabel: l10n.save,
  );
  if (name == null) return;
  await ref.read(databaseProvider).renamePlaylist(playlist.id, name);
}

/// 確認後刪除，回傳是否真的刪除了。
Future<bool> deletePlaylist(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deletePlaylist),
      content: Text(l10n.deletePlaylistConfirm(playlist.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(databaseProvider).deletePlaylist(playlist.id);
  return true;
}

/// 「加入播放清單」：從底部選單選一個清單（或新增一個），把 [songs] 加到最後面。
Future<void> addToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final picked = await showModalBottomSheet<(int, String)>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final playlists = ref.watch(playlistsProvider).value ?? const [];
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l10n.addToPlaylist,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.newPlaylist),
              onTap: () async {
                final navigator = Navigator.of(context);
                final name = await askPlaylistName(
                  context,
                  title: l10n.newPlaylist,
                  confirmLabel: l10n.create,
                );
                if (name == null) return;
                final id = await ref
                    .read(databaseProvider)
                    .createPlaylist(name);
                navigator.pop((id, name));
              },
            ),
            for (final p in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.playlist.name),
                subtitle: Text(l10n.songCount(p.songCount)),
                onTap: () =>
                    Navigator.of(context).pop((p.playlist.id, p.playlist.name)),
              ),
          ],
        );
      },
    ),
  );
  if (picked == null) return;
  final (id, name) = picked;
  await ref.read(databaseProvider).addToPlaylist(id, songs);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.addedToPlaylist(name)),
        duration: const Duration(seconds: 2),
      ),
    );
}
