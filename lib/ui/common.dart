import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../platform/media_store.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../state/playlists.dart';
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

/// 專輯封面；沒有封面時顯示音符圖示。[size] 為 null 時填滿父元件。
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.albumId,
    required this.songId,
    this.size,
    this.radius = 6,
  });

  final int albumId;
  final int songId;
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
          future: MediaStoreChannel.albumArt(albumId, songId),
          initialData: MediaStoreChannel.peekAlbumArt(albumId),
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
  const SongTile({super.key, required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentSongIdProvider) == song.id;
    final color = isCurrent ? Theme.of(context).colorScheme.primary : null;
    return ListTile(
      leading: Artwork(albumId: song.albumId, songId: song.id, size: 48),
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
      trailing: SongMenuButton(song: song),
      onTap: onTap,
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
            ref.read(playerProvider).playNext(song);
            showToast(context, l10n.willPlayNext);
          },
          child: Text(l10n.playNext),
        ),
        PopupMenuItem(
          value: () {
            ref.read(playerProvider).addToQueue(song);
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
        ...?extraItems?.call(),
      ],
    );
  }
}

/// 歌曲清單頁（專輯、歌手、資料夾、搜尋結果共用），最上面有「全部播放」。
class SongListPage extends ConsumerWidget {
  const SongListPage({super.key, required this.title, required this.songs});

  final String title;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
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

class SongList extends ConsumerWidget {
  const SongList({super.key, required this.songs, this.onRefresh});

  final List<Song> songs;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final list = ListView.builder(
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return PlayAllHeader(songs: songs);
        final song = songs[i - 1];
        return SongTile(
          song: song,
          onTap: () => player.playSongs(songs, i - 1),
        );
      },
    );
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
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
                  Artwork(albumId: song.albumId, songId: song.id, size: 44),
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
