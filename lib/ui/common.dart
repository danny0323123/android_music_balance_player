import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../platform/media_store.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../state/playlists.dart';
import 'editing.dart';
import 'playlist_dialogs.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 掃描音樂庫，失敗時跳出錯誤訊息。
Future<void> scanLibrary(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await ref.read(scanProvider.notifier).scan();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.scanFailed('$e'))));
  }
}

String formatDuration(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// 增益顯示成「+3.2 dB」「−4.5 dB」（用真正的減號）。
String formatGain(double db) {
  final rounded = (db * 10).round() / 10;
  if (rounded == 0) return '0 dB';
  final sign = rounded > 0 ? '+' : '−';
  return '$sign${rounded.abs().toStringAsFixed(1)} dB';
}

String artistName(BuildContext context, String? artist) =>
    artist ?? context.l10n.unknownArtist;

String albumName(BuildContext context, String? album) =>
    album ?? context.l10n.unknownAlbum;

/// 歌曲封面；沒有封面時顯示音符圖示。[size] 為 null 時填滿父元件。
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.song, this.size, this.radius = 6});

  final Song song;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = ((size ?? 400) * MediaQuery.devicePixelRatioOf(context))
        .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<String?>(
          future: MediaStoreChannel.albumArt(song),
          initialData: MediaStoreChannel.peekAlbumArt(song),
          builder: (context, snap) {
            final path = snap.data;
            if (path == null) return const _ArtPlaceholder();
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const _ArtPlaceholder(),
            );
          },
        ),
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: LayoutBuilder(
        builder: (context, c) => Icon(
          Icons.music_note,
          color: scheme.onSurfaceVariant,
          size: c.maxWidth * 0.5,
        ),
      ),
    );
  }
}

class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.selected,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 多選模式時不為 null，右邊顯示勾選框取代選單。
  final bool? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentSongIdProvider) == song.id;
    final color = isCurrent ? Theme.of(context).colorScheme.primary : null;
    final selected = this.selected;
    return ListTile(
      selected: selected ?? false,
      leading: Artwork(song: song, size: 48),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color),
      ),
      subtitle: Text(
        '${artistName(context, song.artist)} · ${albumName(context, song.album)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected == null
          ? SongMenuButton(song: song)
          : Checkbox(value: selected, onChanged: (_) => onTap()),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

/// 歌曲的「⋮」選單。[extraItems] 放在最後，例如播放清單頁的「從清單移除」。
class SongMenuButton extends ConsumerWidget {
  const SongMenuButton({super.key, required this.song, this.extraItems});

  final Song song;
  final List<PopupMenuEntry<void Function()>> Function()? extraItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isFavorite = ref.watch(isFavoriteProvider(song.id));
    return PopupMenuButton<void Function()>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: () {
            ref.read(playerProvider).playNext([song]);
            showToast(context, l10n.willPlayNext);
          },
          child: Text(l10n.playNext),
        ),
        PopupMenuItem(
          value: () {
            ref.read(playerProvider).addToQueue([song]);
            showToast(context, l10n.addedToQueue);
          },
          child: Text(l10n.addToQueue),
        ),
        PopupMenuItem(
          value: () => addToPlaylistSheet(context, ref, [song]),
          child: Text(l10n.addToPlaylist),
        ),
        PopupMenuItem(
          value: () =>
              ref.read(databaseProvider).setFavorite(song.id, !isFavorite),
          child: Text(
            isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          ),
        ),
        PopupMenuItem(
          value: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => EditSongPage(song: song))),
          child: Text(l10n.editInfo),
        ),
        PopupMenuItem(
          value: () => deleteSongs(context, ref, [song]),
          child: Text(l10n.delete),
        ),
        ...?extraItems?.call(),
      ],
    );
  }
}

/// 歌曲清單頁（歌手、資料夾共用），最上面有「全部播放」。
/// [songs] 每次音樂庫變動都會重新取，編輯或刪除歌曲後畫面跟著更新。
class SongListPage extends ConsumerWidget {
  const SongListPage({
    super.key,
    required this.title,
    required this.songs,
    this.actions = const [],
  });

  final String title;
  final List<Song> Function(WidgetRef ref) songs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = this.songs(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          IconButton(
            tooltip: context.l10n.addAllToPlaylist,
            icon: const Icon(Icons.playlist_add),
            onPressed: () => addToPlaylistSheet(context, ref, songs),
          ),
        ],
      ),
      body: SongList(songs: songs),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}

/// 清單最上面的一列：歌曲數量、隨機播放、全部播放。
class PlayAllHeader extends ConsumerWidget {
  const PlayAllHeader({super.key, required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final player = ref.read(playerProvider);
    final enabled = songs.isNotEmpty;
    return ListTile(
      title: Text(l10n.songCount(songs.length)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.shuffle,
            onPressed: enabled ? () => player.playShuffled(songs) : null,
            icon: const Icon(Icons.shuffle),
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            onPressed: enabled ? () => player.playSongs(songs, 0) : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.playAll),
          ),
        ],
      ),
    );
  }
}

/// 歌曲清單。長按進入多選，多選時再長按另一首會選取中間的全部。
/// [leading] 放在「全部播放」上面，例如搜尋結果的歌手、專輯。
class SongList extends ConsumerStatefulWidget {
  const SongList({
    super.key,
    required this.songs,
    this.onRefresh,
    this.leading = const [],
  });

  final List<Song> songs;
  final Future<void> Function()? onRefresh;
  final List<Widget> leading;

  @override
  ConsumerState<SongList> createState() => _SongListState();
}

class _SongListState extends ConsumerState<SongList> {
  final _selected = <int>{};
  int _anchor = 0;
  static bool _hintShown = false;

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(int i) => setState(() {
    final id = widget.songs[i].id;
    if (!_selected.remove(id)) _selected.add(id);
    _anchor = i;
  });

  void _longPress(int i) {
    if (!_selecting && !_hintShown) {
      _hintShown = true;
      showToast(context, context.l10n.selectionHint);
    }
    setState(() {
      final (from, to) = _selecting && _anchor < widget.songs.length
          ? (min(_anchor, i), max(_anchor, i))
          : (i, i);
      for (var j = from; j <= to; j++) {
        _selected.add(widget.songs[j].id);
      }
      _anchor = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    // 歌被刪掉後，選取也跟著拿掉
    _selected.retainAll({for (final s in songs) s.id});
    final player = ref.read(playerProvider);
    final leading = widget.leading;
    final list = ListView.builder(
      itemCount: leading.length + songs.length + 1,
      itemBuilder: (context, i) {
        if (i < leading.length) return leading[i];
        i -= leading.length;
        if (i == 0) return PlayAllHeader(songs: songs);
        final index = i - 1;
        final song = songs[index];
        return SongTile(
          song: song,
          selected: _selecting ? _selected.contains(song.id) : null,
          onTap: _selecting
              ? () => _toggle(index)
              : () => player.playSongs(songs, index),
          onLongPress: () => _longPress(index),
        );
      },
    );
    final refresh = widget.onRefresh;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Column(
        children: [
          if (_selecting)
            _SelectionBar(
              songs: [
                for (final s in songs)
                  if (_selected.contains(s.id)) s,
              ],
              onSelectAll: () =>
                  setState(() => _selected.addAll(songs.map((s) => s.id))),
              onClear: () => setState(_selected.clear),
            ),
          Expanded(
            child: refresh == null
                ? list
                : RefreshIndicator(onRefresh: refresh, child: list),
          ),
        ],
      ),
    );
  }
}

/// 多選時顯示在清單上方：加入播放清單、下一首播放、加入佇列、加上標籤、刪除。
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({
    required this.songs,
    required this.onSelectAll,
    required this.onClear,
  });

  final List<Song> songs;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final player = ref.read(playerProvider);
    void done(String? message) {
      onClear();
      if (message != null) showToast(context, message);
    }

    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.clearSelection,
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
          Expanded(child: Text(l10n.selectedCount(songs.length))),
          IconButton(
            tooltip: l10n.selectAll,
            icon: const Icon(Icons.select_all),
            onPressed: onSelectAll,
          ),
          IconButton(
            tooltip: l10n.addToPlaylist,
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              await addToPlaylistSheet(context, ref, songs);
              onClear();
            },
          ),
          PopupMenuButton<void Function()>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () {
                  player.playNext(songs);
                  done(l10n.willPlayNext);
                },
                child: Text(l10n.playNext),
              ),
              PopupMenuItem(
                value: () {
                  player.addToQueue(songs);
                  done(l10n.addedToQueue);
                },
                child: Text(l10n.addToQueue),
              ),
              PopupMenuItem(
                value: () async {
                  await addTagSheet(context, ref, songs);
                  onClear();
                },
                child: Text(l10n.addTags),
              ),
              PopupMenuItem(
                value: () => deleteSongs(context, ref, songs),
                child: Text(l10n.deleteSongs),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayPauseButton extends ConsumerWidget {
  const PlayPauseButton({super.key, this.size = 24, this.filled = false});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playbackStateProvider).value?.playing ?? false;
    final player = ref.read(playerProvider);
    final icon = Icon(playing ? Icons.pause : Icons.play_arrow, size: size);
    void onPressed() => playing ? player.pause() : player.play();
    return filled
        ? IconButton.filled(onPressed: onPressed, icon: icon)
        : IconButton(onPressed: onPressed, icon: icon);
  }
}

/// 畫面底部的迷你播放器，點一下打開完整的播放畫面。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(queueStateProvider).value?.current;
    if (song == null) return const SizedBox.shrink();
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total =
        ref.watch(durationProvider).value ??
        Duration(milliseconds: song.durationMs);
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/now-playing'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Artwork(song: song, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          artistName(context, song.artist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const PlayPauseButton(),
                  IconButton(
                    onPressed: () => ref.read(playerProvider).skipToNext(),
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
