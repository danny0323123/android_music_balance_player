import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 歌曲資料，id 直接沿用 Android MediaStore 的 _ID。
class Songs extends Table {
  IntColumn get id => integer()();
  TextColumn get uri => text()();
  TextColumn get path => text()();
  TextColumn get folder => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get albumId => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get trackNumber => integer()();
  IntColumn get dateAdded => integer()();
  IntColumn get dateModified => integer()();

  // 響度分析結果（第四階段使用）
  RealColumn get lufs => real().nullable()();
  IntColumn get analyzedModified => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 播放清單裡的一個項目。項目有自己的 id，所以同一首歌可以加入多次；
/// 從清單移除只刪除這一列，不會動到歌曲檔案。
/// 歌曲從手機刪除後，項目會留著但不會顯示（查詢時用 inner join 過濾）。
class PlaylistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId => integer()();
  IntColumn get position => integer()();
}

class Favorites extends Table {
  IntColumn get songId => integer()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {songId};
}

class PlaylistSummary {
  const PlaylistSummary(this.playlist, this.songCount);
  final Playlist playlist;
  final int songCount;
}

class PlaylistEntry {
  const PlaylistEntry(this.itemId, this.song);
  final int itemId;
  final Song song;
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistItems, Favorites])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'music_balance'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playlists);
        await m.createTable(playlistItems);
        await m.createTable(favorites);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<Song>> watchSongs() => select(songs).watch();

  /// 依照 ids 的順序取回歌曲，已經不存在的會被略過，重複的 id 會保留。
  Future<List<Song>> songsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final rows = await (select(
      songs,
    )..where((t) => t.id.isIn(ids.toSet()))).get();
    final byId = {for (final s in rows) s.id: s};
    return [for (final id in ids) ?byId[id]];
  }

  /// 用掃描結果更新資料庫：新增或更新現有的歌，刪除已經不在手機上的歌。
  /// 更新時只覆寫掃描得到的欄位，響度分析結果會保留。
  Future<void> replaceLibrary(List<SongsCompanion> scanned) async {
    final scannedIds = {for (final s in scanned) s.id.value};
    final existing = await (selectOnly(
      songs,
    )..addColumns([songs.id])).map((r) => r.read(songs.id)!).get();
    final removed = existing.where((id) => !scannedIds.contains(id)).toList();

    await batch((b) {
      for (final s in scanned) {
        b.insert(songs, s, onConflict: DoUpdate((_) => s));
      }
      for (var i = 0; i < removed.length; i += 500) {
        final chunk = removed.sublist(i, min(i + 500, removed.length));
        b.deleteWhere(songs, (t) => t.id.isIn(chunk));
      }
    });
  }

  // ---------- 響度分析 ----------

  /// 還沒分析，或分析之後檔案被修改過的歌。新加入的排前面。
  Future<List<Song>> songsNeedingAnalysis() =>
      (select(songs)
            ..where(
              (t) =>
                  t.analyzedModified.isNull() |
                  t.analyzedModified.equalsExp(t.dateModified).not(),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)]))
          .get();

  /// 記錄分析結果。[lufs] 為 null 表示無法分析（不會再重試，除非檔案被修改）。
  Future<void> saveLoudness(Song song, double? lufs) =>
      (update(songs)..where((t) => t.id.equals(song.id))).write(
        SongsCompanion(
          lufs: Value(lufs),
          analyzedModified: Value(song.dateModified),
        ),
      );

  Future<void> resetLoudness() => update(songs).write(
    const SongsCompanion(lufs: Value(null), analyzedModified: Value(null)),
  );

  // ---------- 播放清單 ----------

  Stream<List<PlaylistSummary>> watchPlaylists() {
    final count = songs.id.count();
    final query =
        select(playlists).join([
            leftOuterJoin(
              playlistItems,
              playlistItems.playlistId.equalsExp(playlists.id),
            ),
            leftOuterJoin(songs, songs.id.equalsExp(playlistItems.songId)),
          ])
          ..addColumns([count])
          ..groupBy([playlists.id])
          ..orderBy([OrderingTerm.asc(playlists.createdAt)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          PlaylistSummary(r.readTable(playlists), r.read(count) ?? 0),
      ],
    );
  }

  Stream<List<PlaylistEntry>> watchPlaylistEntries(int playlistId) {
    final query =
        select(playlistItems)
            .join([innerJoin(songs, songs.id.equalsExp(playlistItems.songId))])
          ..where(playlistItems.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistItems.position)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          PlaylistEntry(r.readTable(playlistItems).id, r.readTable(songs)),
      ],
    );
  }

  Future<int> createPlaylist(String name) =>
      into(playlists).insert(PlaylistsCompanion.insert(name: name));

  Future<void> renamePlaylist(int id, String name) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(
        PlaylistsCompanion(name: Value(name)),
      );

  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((t) => t.id.equals(id))).go();

  /// 加到清單最後面。
  Future<void> addToPlaylist(int playlistId, List<Song> toAdd) async {
    await transaction(() async {
      final maxPos = playlistItems.position.max();
      final last =
          await (selectOnly(playlistItems)
                ..addColumns([maxPos])
                ..where(playlistItems.playlistId.equals(playlistId)))
              .map((r) => r.read(maxPos))
              .getSingle() ??
          -1;
      await batch((b) {
        for (final (i, song) in toAdd.indexed) {
          b.insert(
            playlistItems,
            PlaylistItemsCompanion.insert(
              playlistId: playlistId,
              songId: song.id,
              position: last + 1 + i,
            ),
          );
        }
      });
    });
  }

  Future<void> removePlaylistItem(int itemId) =>
      (delete(playlistItems)..where((t) => t.id.equals(itemId))).go();

  /// [itemIds] 是排序後的完整項目順序。
  Future<void> reorderPlaylist(List<int> itemIds) => batch((b) {
    for (final (i, itemId) in itemIds.indexed) {
      b.update(
        playlistItems,
        PlaylistItemsCompanion(position: Value(i)),
        where: (t) => t.id.equals(itemId),
      );
    }
  });

  // ---------- 我的最愛 ----------

  Stream<Set<int>> watchFavoriteIds() =>
      select(favorites).map((f) => f.songId).watch().map((ids) => ids.toSet());

  /// 最近加入的排在最前面。
  Stream<List<Song>> watchFavoriteSongs() {
    final query = select(favorites).join([
      innerJoin(songs, songs.id.equalsExp(favorites.songId)),
    ])..orderBy([OrderingTerm.desc(favorites.addedAt)]);
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(songs)],
    );
  }

  Future<void> setFavorite(int songId, bool favorite) => favorite
      ? into(favorites).insertOnConflictUpdate(
          FavoritesCompanion.insert(songId: Value(songId)),
        )
      : (delete(favorites)..where((t) => t.songId.equals(songId))).go();
}
