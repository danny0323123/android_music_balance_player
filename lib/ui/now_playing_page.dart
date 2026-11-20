import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_handler.dart';
import '../state/library.dart';
import '../state/loudness.dart';
import '../state/player.dart';
import '../state/playlists.dart';
import 'common.dart';
import 'playlist_dialogs.dart';

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final song = ref.watch(queueStateProvider).value?.current;
    final player = ref.read(playerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.nowPlaying),
        actions: [
          if (song != null) ...[
            _FavoriteButton(songId: song.id),
            IconButton(
              tooltip: l10n.addToPlaylist,
              icon: const Icon(Icons.playlist_add),
              onPressed: () => addToPlaylistSheet(context, ref, [song]),
            ),
          ],
          IconButton(
            tooltip: l10n.queue,
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.of(context).pushNamed('/queue'),
          ),
        ],
      ),
      body: song == null
          ? Center(child: Text(l10n.emptyQueue))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Artwork(song: song, radius: 16),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      song.title,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${artistName(context, song.artist)} · ${albumName(context, song.album)}',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const _NormalizationLabel(),
                    const SizedBox(height: 16),
                    _SeekBar(fallback: Duration(milliseconds: song.durationMs)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const _ShuffleButton(),
                        IconButton(
                          iconSize: 36,
                          onPressed: player.skipToPrevious,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        const PlayPauseButton(size: 40, filled: true),
                        IconButton(
                          iconSize: 36,
                          onPressed: player.skipToNext,
                          icon: const Icon(Icons.skip_next),
                        ),
                        const _RepeatButton(),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 「音量均衡 −3.2 dB」：讓使用者看到這首歌被調整了多少。關閉時不顯示。
class _NormalizationLabel extends ConsumerWidget {
  const _NormalizationLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final info = ref.watch(normalizationInfoProvider).value;
    final text = switch (info?.status) {
      null || NormalizationStatus.off => null,
      NormalizationStatus.analyzing => l10n.normalizationAnalyzing,
      NormalizationStatus.failed => l10n.normalizationFailed,
      NormalizationStatus.applied => l10n.normalizationGain(
        formatGain(info!.gainDb),
      ),
    };
    if (text == null) return const SizedBox(height: 20);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.graphic_eq, size: 16, color: scheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorite = ref.watch(isFavoriteProvider(songId));
    return IconButton(
      tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
      color: favorite ? Theme.of(context).colorScheme.primary : null,
      onPressed: () =>
          ref.read(databaseProvider).setFavorite(songId, !favorite),
    );
  }
}

/// 隨機開關：打開時把佇列打亂（目前這首排第一），關掉時恢復原本順序。
class _ShuffleButton extends ConsumerWidget {
  const _ShuffleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(queueStateProvider).value?.shuffled ?? false;
    return IconButton(
      tooltip: on ? l10n.shuffleOn : l10n.shuffleOff,
      isSelected: on,
      onPressed: () => ref
          .read(playerProvider)
          .setShuffleMode(
            on ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
          ),
      icon: Icon(
        Icons.shuffle,
        color: on ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}

class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.fallback});

  final Duration fallback;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = ref.watch(durationProvider).value ?? widget.fallback;
    final max = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final value =
        _dragValue ?? position.inMilliseconds.toDouble().clamp(0.0, max);
    final style = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        Slider(
          max: max,
          value: value,
          onChanged: (v) => setState(() => _dragValue = v),
          onChangeEnd: (v) {
            ref.read(playerProvider).seek(Duration(milliseconds: v.round()));
            setState(() => _dragValue = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: value.round())),
                style: style,
              ),
              Text(formatDuration(total), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepeatButton extends ConsumerWidget {
  const _RepeatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode =
        ref.watch(playbackStateProvider).value?.repeatMode ??
        AudioServiceRepeatMode.none;
    final (icon, tooltip, next) = switch (mode) {
      AudioServiceRepeatMode.one => (
        Icons.repeat_one,
        l10n.repeatOne,
        AudioServiceRepeatMode.none,
      ),
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => (
        Icons.repeat,
        l10n.repeatAll,
        AudioServiceRepeatMode.one,
      ),
      AudioServiceRepeatMode.none => (
        Icons.repeat,
        l10n.repeatOff,
        AudioServiceRepeatMode.all,
      ),
    };
    final active = mode != AudioServiceRepeatMode.none;
    return IconButton(
      tooltip: tooltip,
      isSelected: active,
      onPressed: () => ref.read(playerProvider).setRepeatMode(next),
      icon: Icon(
        icon,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
