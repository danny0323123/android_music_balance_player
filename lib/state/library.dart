import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/library_groups.dart';
import '../platform/media_store.dart';
import 'loudness.dart';
import 'player.dart';
import 'settings.dart';

export '../data/library_groups.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(),
);

final allSongsProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(databaseProvider).watchSongs(),
);

/// 套用排除規則（太短的音檔、排除的資料夾）之後的歌曲。
final librarySongsProvider = Provider<List<Song>>(
  (ref) => filterLibrary(
    ref.watch(allSongsProvider).value ?? const [],
    ref.watch(settingsProvider),
  ),
);

/// 「歌曲」分頁使用，依照使用者選的方式排序。
final sortedSongsProvider = Provider<List<Song>>(
  (ref) =>
      sortSongs(ref.watch(librarySongsProvider), ref.watch(settingsProvider)),
);

final albumsProvider = Provider<List<Album>>(
  (ref) => groupAlbums(ref.watch(librarySongsProvider)),
);

final artistsProvider = Provider<List<Artist>>(
  (ref) => groupArtists(ref.watch(librarySongsProvider)),
);

final foldersProvider = Provider<List<Folder>>(
  (ref) => groupFolders(ref.watch(librarySongsProvider)),
);

/// 包含已排除的資料夾，給「排除的資料夾」設定頁使用。
final allFoldersProvider = Provider<List<Folder>>(
  (ref) => groupFolders(ref.watch(allSongsProvider).value ?? const []),
);

/// 是否正在掃描音樂庫。
class ScanNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> scan() async {
    if (state) return;
    state = true;
    try {
      final db = ref.read(databaseProvider);
      final scanned = await MediaStoreChannel.queryAudio(
        await db.fingerprintedSongs(),
      );
      await db.replaceLibrary(scanned);
    } finally {
      state = false;
    }
    await ref.read(playerProvider).refreshSongs();
    // 掃描完接著在背景分析新加入（或被修改過）的歌的響度
    unawaited(ref.read(loudnessProvider).start());
  }
}

final scanProvider = NotifierProvider<ScanNotifier, bool>(ScanNotifier.new);
