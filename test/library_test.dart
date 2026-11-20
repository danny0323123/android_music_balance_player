import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/data/database.dart';
import 'package:music_balance/state/library.dart';
import 'package:music_balance/ui/common.dart';

SongsCompanion _song(
  int id, {
  String title = 't',
  int modified = 1,
  String? fingerprint,
  String? album,
  String? albumArtist,
}) => SongsCompanion.insert(
  id: Value(id),
  uri: 'content://media/external/audio/media/$id',
  path: '/storage/emulated/0/Music/$id.mp3',
  folder: '/storage/emulated/0/Music',
  title: title,
  album: Value(album),
  albumArtist: Value(albumArtist),
  albumId: 1,
  durationMs: 180000,
  trackNumber: 0,
  dateAdded: 1,
  dateModified: modified,
  fingerprint: fingerprint == null ? const Value.absent() : Value(fingerprint),
  fingerprintModified: fingerprint == null
      ? const Value.absent()
      : Value(modified),
);

void main() {
  group('replaceLibrary', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('adds new songs and removes songs no longer on the phone', () async {
      await db.replaceLibrary([_song(1), _song(2), _song(3)]);
      await db.replaceLibrary([_song(2), _song(3), _song(4)]);
      final ids = (await db.select(db.songs).get()).map((s) => s.id).toSet();
      expect(ids, {2, 3, 4});
    });

    test('updates metadata but keeps loudness analysis', () async {
      await db.replaceLibrary([_song(1, title: 'old')]);
      await (db.update(db.songs)..where((t) => t.id.equals(1))).write(
        const SongsCompanion(lufs: Value(-9.5)),
      );

      await db.replaceLibrary([_song(1, title: 'new')]);
      final song = await db.select(db.songs).getSingle();
      expect(song.title, 'new');
      expect(song.lufs, -9.5);
    });

    test(
      'songsByIds keeps queue order and duplicates, skips missing',
      () async {
        await db.replaceLibrary([_song(1), _song(2), _song(3)]);
        final songs = await db.songsByIds([3, 1, 99, 3]);
        expect(songs.map((s) => s.id), [3, 1, 3]);
      },
    );
  });

  group('playlists', () {
    late AppDatabase db;
    late List<Song> songs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.replaceLibrary([_song(1), _song(2), _song(3)]);
      songs = await db.songsByIds([1, 2, 3]);
    });
    tearDown(() => db.close());

    Future<List<int>> entryIds(int playlistId) async => [
      for (final e in await db.watchPlaylistEntries(playlistId).first)
        e.song.id,
    ];

    test('appends songs in order and allows duplicates', () async {
      final id = await db.createPlaylist('Drive');
      await db.addToPlaylist(id, [songs[0], songs[1]]);
      await db.addToPlaylist(id, [songs[0]]);
      expect(await entryIds(id), [1, 2, 1]);
      final summary = (await db.watchPlaylists().first).single;
      expect(summary.playlist.name, 'Drive');
      expect(summary.songCount, 3);
    });

    test('reorder and remove only touch playlist items', () async {
      final id = await db.createPlaylist('Drive');
      await db.addToPlaylist(id, songs);
      final entries = await db.watchPlaylistEntries(id).first;
      await db.reorderPlaylist([
        entries[2].itemId,
        entries[0].itemId,
        entries[1].itemId,
      ]);
      expect(await entryIds(id), [3, 1, 2]);

      await db.removePlaylistItem(entries[0].itemId);
      expect(await entryIds(id), [3, 2]);
      expect((await db.select(db.songs).get()).length, 3);
    });

    test('songs deleted from the phone disappear from playlists', () async {
      final id = await db.createPlaylist('Drive');
      await db.addToPlaylist(id, songs);
      await db.replaceLibrary([_song(1), _song(3)]);
      expect(await entryIds(id), [1, 3]);
      expect((await db.watchPlaylists().first).single.songCount, 2);
    });

    test('deleting a playlist removes its items', () async {
      final id = await db.createPlaylist('Drive');
      await db.addToPlaylist(id, songs);
      await db.deletePlaylist(id);
      expect(await db.watchPlaylists().first, isEmpty);
      expect(await db.select(db.playlistItems).get(), isEmpty);
    });

    test('favorites toggle and list newest first', () async {
      await db.setFavorite(1, true);
      await Future<void>.delayed(const Duration(seconds: 1));
      await db.setFavorite(3, true);
      expect(await db.watchFavoriteIds().first, {1, 3});
      expect(
        [for (final s in await db.watchFavoriteSongs().first) s.id],
        [3, 1],
      );
      await db.setFavorite(1, false);
      expect(await db.watchFavoriteIds().first, {3});
    });
  });

  group('fingerprints, tags, backup', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('only rescans fingerprints of songs that changed', () async {
      await db.replaceLibrary([_song(1, fingerprint: 'a'), _song(2)]);
      expect(await db.fingerprintedSongs(), {1: 1});
      // 這次原生端沒有重算（absent），保留原本的指紋
      await db.replaceLibrary([_song(1), _song(2)]);
      final song = (await db.songsByIds([1])).single;
      expect(song.fingerprint, 'a');
    });

    test('a moved file keeps its playlists, favorite and tags', () async {
      await db.replaceLibrary([_song(1, fingerprint: 'a'), _song(2)]);
      final list = await db.createPlaylist('Drive');
      await db.addToPlaylist(list, await db.songsByIds([1, 2]));
      await db.setFavorite(1, true);
      final tag = await db.createTag('chill');
      await db.addTagToSongs(tag, [1]);

      // 搬到別的資料夾後系統給了新的 id 7
      await db.replaceLibrary([_song(7, fingerprint: 'a'), _song(2)]);

      expect(
        [for (final e in await db.watchPlaylistEntries(list).first) e.song.id],
        [7, 2],
      );
      expect(await db.watchFavoriteIds().first, {7});
      expect(await db.watchTagSongs().first, {
        tag: {7},
      });
    });

    test('tags count only songs still on the phone', () async {
      await db.replaceLibrary([_song(1), _song(2)]);
      final tag = await db.createTag('chill');
      expect(await db.createTag('chill'), tag);
      await db.addTagToSongs(tag, [1, 2]);
      await db.replaceLibrary([_song(1)]);
      expect((await db.watchTags().first).single.songCount, 1);
      await db.setSongTags(1, {});
      expect(await db.tagIdsOf(1), isEmpty);
    });

    test('backup round-trips by fingerprint onto another phone', () async {
      await db.replaceLibrary([
        _song(1, fingerprint: 'a'),
        _song(2, fingerprint: 'b'),
      ]);
      final list = await db.createPlaylist('Drive');
      await db.addToPlaylist(list, await db.songsByIds([2, 1]));
      await db.setFavorite(2, true);
      await db.addTagToSongs(await db.createTag('chill'), [1]);
      final backup = await db.exportBackup();

      // 新手機：同樣的歌、不同的 id，少了 b
      final other = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(other.close);
      await other.replaceLibrary([_song(50, fingerprint: 'a')]);
      final result = await other.importBackup(backup);

      expect(result.found, 1);
      expect(result.missing, 1);
      final playlist = (await other.watchPlaylists().first).single;
      expect(playlist.playlist.name, 'Drive');
      expect(
        [
          for (final e
              in await other.watchPlaylistEntries(playlist.playlist.id).first)
            e.song.id,
        ],
        [50],
      );
      expect(await other.watchFavoriteIds().first, isEmpty);
      final tags = await other.watchTags().first;
      expect(tags.single.tag.name, 'chill');
      expect(tags.single.songCount, 1);
    });
  });

  test('albums group by name and album artist', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.replaceLibrary([
      _song(1, album: 'Hits'),
      _song(2, album: 'Hits'),
      _song(3, album: 'Hits', albumArtist: 'Band'),
    ]);
    final albums = groupAlbums(await db.select(db.songs).get());
    expect(albums.map((a) => a.songs.length), unorderedEquals([2, 1]));
    expect(albums.map((a) => a.key).toSet(), {'Hits\u0000', 'Hits\u0000Band'});
  });

  test('filterByTags matches all tags, or any when asked', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.replaceLibrary([_song(1), _song(2), _song(3)]);
    final songs = await db.select(db.songs).get();
    final tagSongs = {
      10: {1, 2},
      20: {2, 3},
    };
    List<int> ids(Set<int> tags, {bool any = false}) => [
      for (final s in filterByTags(songs, tagSongs, tags, matchAny: any)) s.id,
    ];
    expect(ids({10, 20}), [2]);
    expect(ids({10, 20}, any: true), [1, 2, 3]);
    expect(ids({}), isEmpty);
  });

  test('isFolderExcluded matches the folder and its subfolders only', () {
    const excluded = {'/sdcard/Recordings'};
    expect(isFolderExcluded('/sdcard/Recordings', excluded), isTrue);
    expect(isFolderExcluded('/sdcard/Recordings/Call', excluded), isTrue);
    expect(isFolderExcluded('/sdcard/Recordings2', excluded), isFalse);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
