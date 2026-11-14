import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_handler.dart';
import '../state/player.dart';
import 'common.dart';
import 'playlist_dialogs.dart';

/// 播放佇列：點一下跳到那首歌、拖曳把手調整順序、按 X 從佇列移除。
class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  late QueueState _queue;
  late final StreamSubscription<QueueState> _sub;
  late final ScrollController _scroll;

  static const _itemExtent = 72.0;

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider);
    _queue = player.queueState.value;
    _scroll = ScrollController(
      initialScrollOffset: max(0, (_queue.index - 2) * _itemExtent),
    );
    // 自己訂閱而不是用 StreamBuilder：拖曳排序後要立刻更新畫面，不能等下一次事件
    _sub = player.queueState.listen((q) => setState(() => _queue = q));
  }

  @override
  void dispose() {
    _sub.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = ref.read(playerProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.queue),
        actions: [
          IconButton(
            tooltip: l10n.saveQueueAsPlaylist,
            icon: const Icon(Icons.playlist_add),
            onPressed: _queue.songs.isEmpty
                ? null
                : () => addToPlaylistSheet(context, ref, _queue.songs),
          ),
        ],
      ),
      body: _queue.songs.isEmpty
          ? Center(child: Text(l10n.emptyQueue))
          : ReorderableListView.builder(
              scrollController: _scroll,
              buildDefaultDragHandles: false,
              itemExtent: _itemExtent,
              itemCount: _queue.songs.length,
              onReorderItem: (from, to) {
                player.moveQueueItem(from, to);
                setState(() => _queue = player.queueState.value);
              },
              itemBuilder: (context, i) {
                final song = _queue.songs[i];
                final isCurrent = i == _queue.index;
                return ListTile(
                  key: ValueKey('$i-${song.id}'),
                  leading: Artwork(
                    albumId: song.albumId,
                    songId: song.id,
                    size: 48,
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isCurrent ? primary : null),
                  ),
                  subtitle: Text(
                    artistName(context, song.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => player.skipToQueueItem(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.removeFromQueue,
                        icon: const Icon(Icons.close),
                        onPressed: () => player.removeQueueItemAt(i),
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
    );
  }
}
