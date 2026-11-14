import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/data/database.dart';
import 'package:music_balance/state/library.dart';
import 'package:music_balance/ui/common.dart';

SongsCompanion _song(int id, {String title = 't', int modified = 1}) =>
    SongsCompanion.insert(
      id: Value(id),
      uri: 'content://media/external/audio/media/$id',
      path: '/storage/emulated/0/Music/$id.mp3',
      folder: '/storage/emulated/0/Music',
      title: title,
      albumId: 1,
      durationMs: 180000,
      trackNumber: 0,
      dateAdded: 1,
      dateModified: modified,
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
