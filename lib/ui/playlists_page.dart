import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../state/playlists.dart';
import 'common.dart';
import 'playlist_dialogs.dart';
import 'tags_page.dart';

/// 「播放清單」分頁：最上面是我的最愛，接著是自己建立的清單。
class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final favoriteCount = ref.watch(favoriteSongsProvider).value?.length ?? 0;
    final tagCount = ref.watch(tagsProvider).value?.length ?? 0;

    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.favorite)),
          title: Text(l10n.favorites),
          subtitle: Text(l10n.songCount(favoriteCount)),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FavoritesPage())),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.sell)),
          title: Text(l10n.tags),
          subtitle: Text('$tagCount'),
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const TagsPage())),
        ),
        for (final p in playlists)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.queue_music)),
            title: Text(p.playlist.name),
            subtitle: Text(l10n.songCount(p.songCount)),
            trailing: _PlaylistMenu(playlist: p.playlist),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistPage(playlist: p.playlist),
              ),
            ),
          ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.add)),
          title: Text(l10n.newPlaylist),
          onTap: () => createPlaylist(context, ref),
        ),
      ],
    );
  }
}

class _PlaylistMenu extends ConsumerWidget {
  const _PlaylistMenu({required this.playlist, this.onDeleted});

  final Playlist playlist;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<void Function()>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: () => renamePlaylist(context, ref, playlist),
          child: Text(l10n.rename),
        ),
        PopupMenuItem(
          value: () async {
            if (await deletePlaylist(context, ref, playlist)) onDeleted?.call();
          },
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// 單一播放清單：拖曳把手調整順序，「⋮」選單可以從清單移除。
class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  /// 拖曳排序後先在畫面上套用，等資料庫回傳新順序後清掉，避免畫面跳回原位。
  List<PlaylistEntry>? _reordered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.playlist.id;
    ref.listen(playlistEntriesProvider(id), (_, _) {
      if (_reordered != null) setState(() => _reordered = null);
    });
    final entries =
        _reordered ?? ref.watch(playlistEntriesProvider(id)).value ?? const [];
    final songs = [for (final e in entries) e.song];
    // 名稱可能被改過，從清單資料取最新的
    final name =
        ref
            .watch(playlistsProvider)
            .value
            ?.where((p) => p.playlist.id == id)
            .firstOrNull
            ?.playlist
            .name ??
        widget.playlist.name;
    final player = ref.read(playerProvider);
    final currentId = ref.watch(currentSongIdProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          _PlaylistMenu(
            playlist: widget.playlist.copyWith(name: name),
            onDeleted: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text(l10n.playlistEmpty))
          : ReorderableListView.builder(
              header: PlayAllHeader(songs: songs),
              buildDefaultDragHandles: false,
              itemCount: entries.length,
              onReorderItem: (from, to) {
                final list = [...entries];
                list.insert(to, list.removeAt(from));
                setState(() => _reordered = list);
                ref.read(databaseProvider).reorderPlaylist([
                  for (final e in list) e.itemId,
                ]);
              },
              itemBuilder: (context, i) {
                final entry = entries[i];
                final song = entry.song;
                return ListTile(
                  key: ValueKey(entry.itemId),
                  leading: Artwork(song: song, size: 48),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song.id == currentId ? primary : null,
                    ),
                  ),
                  subtitle: Text(
                    artistName(context, song.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => player.playSongs(songs, i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SongMenuButton(
                        song: song,
                        extraItems: () => [
                          PopupMenuItem(
                            value: () => ref
                                .read(databaseProvider)
                                .removePlaylistItem(entry.itemId),
                            child: Text(l10n.removeFromPlaylist),
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final songs = ref.watch(favoriteSongsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: songs.isEmpty
          ? Center(child: Text(l10n.favoritesEmpty))
          : SongList(songs: songs),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}
