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

  // 從檔案標籤讀出來的（可在 app 裡編輯，會寫回檔案）
  TextColumn get albumArtist => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();

  /// 音訊指紋（見原生端 Fingerprint）：檔案搬移、換手機時用來對回播放清單、標籤。
  TextColumn get fingerprint => text().nullable()();

  /// 算指紋時檔案的修改時間，檔案改過才重算。
  IntColumn get fingerprintModified => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 自訂標籤，只存在 app 裡（不寫進檔案）。
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class SongTags extends Table {
  IntColumn get songId => integer()();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {songId, tagId};
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

class TagSummary {
  const TagSummary(this.tag, this.songCount);
  final Tag tag;
  final int songCount;
}

/// 匯入備份的結果：[missing] 是備份裡有、但這支手機上找不到的歌數。
class ImportResult {
  const ImportResult(this.found, this.missing);
  final int found;
  final int missing;
}

@DriftDatabase(
  tables: [Songs, Playlists, PlaylistItems, Favorites, Tags, SongTags],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'music_balance'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playlists);
        await m.createTable(playlistItems);
        await m.createTable(favorites);
      }
      if (from < 3) {
        await m.addColumn(songs, songs.albumArtist);
        await m.addColumn(songs, songs.genre);
        await m.addColumn(songs, songs.year);
        await m.addColumn(songs, songs.fingerprint);
        await m.addColumn(songs, songs.fingerprintModified);
        await m.createTable(tags);
        await m.createTable(songTags);
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

  /// 已經算過指紋的歌：id → 算指紋時的修改時間，掃描時傳給原生端，沒改過的就不重算。
  Future<Map<int, int>> fingerprintedSongs() async {
    final rows =
        await (selectOnly(songs)
              ..addColumns([songs.id, songs.fingerprintModified])
              ..where(songs.fingerprintModified.isNotNull()))
            .get();
    return {
      for (final r in rows)
        r.read(songs.id)!: r.read(songs.fingerprintModified)!,
    };
  }

  /// 用掃描結果更新資料庫：新增或更新現有的歌，刪除已經不在手機上的歌。
  /// 更新時只覆寫掃描得到的欄位，響度分析結果會保留。
  /// 檔案搬移後系統會給新的 id：用指紋找回來，播放清單、我的最愛、標籤改指向新的 id。
  Future<void> replaceLibrary(List<SongsCompanion> scanned) async {
    final scannedIds = {for (final s in scanned) s.id.value};
    final existing = await (selectOnly(
      songs,
    )..addColumns([songs.id])).map((r) => r.read(songs.id)!).get();
    final existingIds = existing.toSet();
    final removed = existing.where((id) => !scannedIds.contains(id)).toList();

    final added = {
      for (final s in scanned)
        if (!existingIds.contains(s.id.value) && s.fingerprint.value != null)
          s.fingerprint.value!: s.id.value,
    };
    final moved = <(int, int)>[];
    if (added.isNotEmpty && removed.isNotEmpty) {
      final gone = await (select(
        songs,
      )..where((t) => t.id.isIn(removed) & t.fingerprint.isNotNull())).get();
      for (final s in gone) {
        final to = added[s.fingerprint];
        if (to != null) moved.add((s.id, to));
      }
    }

    await transaction(() async {
      await batch((b) {
        for (final s in scanned) {
          b.insert(songs, s, onConflict: DoUpdate((_) => s));
        }
        for (var i = 0; i < removed.length; i += 500) {
          final chunk = removed.sublist(i, min(i + 500, removed.length));
          b.deleteWhere(songs, (t) => t.id.isIn(chunk));
        }
      });
      for (final (from, to) in moved) {
        await _moveReferences(from, to);
      }
    });
  }

  Future<void> _moveReferences(int from, int to) async {
    final args = [Variable.withInt(to), Variable.withInt(from)];
    await customUpdate(
      'UPDATE playlist_items SET song_id = ? WHERE song_id = ?',
      variables: args,
      updates: {playlistItems},
    );
    // 新的 id 可能已經有同樣的紀錄（主鍵衝突），這時留新的、刪舊的
    for (final table in ['favorites', 'song_tags']) {
      await customUpdate(
        'UPDATE OR IGNORE $table SET song_id = ? WHERE song_id = ?',
        variables: args,
        updates: {favorites, songTags},
      );
      await customUpdate(
        'DELETE FROM $table WHERE song_id = ?',
        variables: [Variable.withInt(from)],
        updates: {favorites, songTags},
      );
    }
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

  // ---------- 標籤 ----------

  /// 依名稱排序，數量只算還在手機上的歌。
  Stream<List<TagSummary>> watchTags() {
    final count = songs.id.count();
    final query =
        select(tags).join([
            leftOuterJoin(songTags, songTags.tagId.equalsExp(tags.id)),
            leftOuterJoin(songs, songs.id.equalsExp(songTags.songId)),
          ])
          ..addColumns([count])
          ..groupBy([tags.id])
          ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows) TagSummary(r.readTable(tags), r.read(count) ?? 0),
      ],
    );
  }

  /// 標籤 id → 有這個標籤的歌曲 id。
  Stream<Map<int, Set<int>>> watchTagSongs() =>
      select(songTags).watch().map((rows) {
        final map = <int, Set<int>>{};
        for (final r in rows) {
          map.putIfAbsent(r.tagId, () => {}).add(r.songId);
        }
        return map;
      });

  /// 已經有同名的標籤就回傳它的 id。
  Future<int> createTag(String name) async {
    await into(
      tags,
    ).insert(TagsCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
    return (await (select(
      tags,
    )..where((t) => t.name.equals(name))).getSingle()).id;
  }

  Future<void> deleteTag(int id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  Future<Set<int>> tagIdsOf(int songId) async => {
    for (final r in await (select(
      songTags,
    )..where((t) => t.songId.equals(songId))).get())
      r.tagId,
  };

  Future<void> setSongTags(int songId, Set<int> tagIds) =>
      transaction(() async {
        await (delete(songTags)..where((t) => t.songId.equals(songId))).go();
        await batch((b) {
          for (final tagId in tagIds) {
            b.insert(
              songTags,
              SongTagsCompanion.insert(songId: songId, tagId: tagId),
            );
          }
        });
      });

  Future<void> addTagToSongs(int tagId, Iterable<int> songIds) => batch((b) {
    for (final songId in songIds) {
      b.insert(
        songTags,
        SongTagsCompanion.insert(songId: songId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });

  // ---------- 備份 ----------

  /// 播放清單、我的最愛、標籤，歌曲用指紋記錄，換手機也對得回來。
  Future<Map<String, Object?>> exportBackup() async {
    final fingerprints = {
      for (final s in await select(songs).get())
        if (s.fingerprint != null) s.id: s.fingerprint!,
    };
    List<String> keys(Iterable<int> ids) => [
      for (final id in ids) ?fingerprints[id],
    ];

    final lists = await (select(
      playlists,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    final items = await (select(
      playlistItems,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final tagRows = await select(tags).get();
    final songTagRows = await select(songTags).get();
    return {
      'version': 1,
      'playlists': [
        for (final p in lists)
          {
            'name': p.name,
            'songs': keys([
              for (final i in items)
                if (i.playlistId == p.id) i.songId,
            ]),
          },
      ],
      'favorites': keys([
        for (final f in await select(favorites).get()) f.songId,
      ]),
      'tags': [
        for (final t in tagRows)
          {
            'name': t.name,
            'songs': keys([
              for (final st in songTagRows)
                if (st.tagId == t.id) st.songId,
            ]),
          },
      ],
    };
  }

  /// 合併進現有資料：同名的播放清單會被備份內容取代，我的最愛、標籤則是加上去。
  Future<ImportResult> importBackup(Map<String, Object?> backup) async {
    final byFingerprint = <String, int>{};
    for (final s in await select(songs).get()) {
      if (s.fingerprint case final f?) byFingerprint.putIfAbsent(f, () => s.id);
    }
    final seen = <String>{};
    final missing = <String>{};
    List<int> ids(Object? list) {
      final result = <int>[];
      for (final key in (list as List? ?? const []).cast<String>()) {
        seen.add(key);
        final id = byFingerprint[key];
        id == null ? missing.add(key) : result.add(id);
      }
      return result;
    }

    Iterable<Map<String, Object?>> entries(String key) =>
        (backup[key] as List? ?? const []).cast<Map<String, Object?>>();

    await transaction(() async {
      for (final p in entries('playlists')) {
        final name = p['name'] as String;
        final songIds = ids(p['songs']);
        final old = await (select(
          playlists,
        )..where((t) => t.name.equals(name))).getSingleOrNull();
        final id = old?.id ?? await createPlaylist(name);
        await (delete(
          playlistItems,
        )..where((t) => t.playlistId.equals(id))).go();
        await batch((b) {
          for (final (i, songId) in songIds.indexed) {
            b.insert(
              playlistItems,
              PlaylistItemsCompanion.insert(
                playlistId: id,
                songId: songId,
                position: i,
              ),
            );
          }
        });
      }
      for (final songId in ids(backup['favorites'])) {
        await into(favorites).insert(
          FavoritesCompanion.insert(songId: Value(songId)),
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (final t in entries('tags')) {
        final tagId = await createTag(t['name'] as String);
        await addTagToSongs(tagId, ids(t['songs']));
      }
    });
    return ImportResult(seen.length - missing.length, missing.length);
  }
}
