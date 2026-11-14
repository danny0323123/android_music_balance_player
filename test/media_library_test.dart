import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/audio/media_library.dart';
import 'package:music_balance/data/database.dart';
import 'package:music_balance/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

SongsCompanion _song(
  int id,
  String title, {
  String? artist,
  int albumId = 1,
  String folder = '/Music',
  int durationMs = 180000,
}) => SongsCompanion.insert(
  id: Value(id),
  uri: 'content://media/external/audio/media/$id',
  path: '$folder/$id.mp3',
  folder: folder,
  title: title,
  artist: Value(artist),
  album: Value('Album $albumId'),
  albumId: albumId,
  durationMs: durationMs,
  trackNumber: id,
  dateAdded: id,
  dateModified: 1,
);

void main() {
  late AppDatabase db;
  late MediaLibrary library;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.replaceLibrary([
      _song(1, 'Bravo', artist: 'AC/DC | Live', albumId: 10),
      _song(2, 'Alpha', artist: 'AC/DC | Live', albumId: 10),
      _song(3, 'Charlie', albumId: 20),
      _song(4, 'Ringtone-ish', durationMs: 5000),
      _song(5, 'Hidden', folder: '/Recordings'),
    ]);
    SharedPreferences.setMockInitialValues({
      SettingsKeys.excludedFolders: ['/Recordings'],
    });
    library = MediaLibrary(db, await SharedPreferences.getInstance());
  });
  tearDown(() => db.close());

  List<String> ids(List<MediaItem> items) => [for (final i in items) i.id];

  test('root has the four tabs, none playable', () async {
    final root = await library.children(AudioService.browsableRootId);
    expect(ids(root), [
      MediaIds.songs,
      MediaIds.playlists,
      MediaIds.albums,
      MediaIds.artists,
    ]);
    expect(root.every((i) => i.playable == false), isTrue);
  });

  test('songs tab applies exclusions and sort, with shuffle first', () async {
    final items = await library.children(MediaIds.songs);
    expect(ids(items), [
      MediaIds.shuffle(MediaIds.songs),
      MediaIds.song(MediaIds.songs, 2), // Alpha
      MediaIds.song(MediaIds.songs, 1), // Bravo
      MediaIds.song(MediaIds.songs, 3), // Charlie
    ]);
  });

  test('tapping a song plays its folder from that song', () async {
    final request = await library.resolve(MediaIds.song(MediaIds.songs, 1));
    expect([for (final s in request!.songs) s.id], [2, 1, 3]);
    expect(request.index, 1);
    expect(request.shuffle, isFalse);
  });

  test('shuffle item resolves to the whole folder', () async {
    final request = await library.resolve(MediaIds.shuffle(MediaIds.songs));
    expect(request!.shuffle, isTrue);
    expect(request.songs, hasLength(3));
  });

  test('artist names with separators round-trip', () async {
    final artists = await library.children(MediaIds.artists);
    final acdc = artists.firstWhere((a) => a.title == 'AC/DC | Live');
    final songs = await library.children(acdc.id);
    expect(songs.first.id, MediaIds.shuffle(acdc.id));
    final request = await library.resolve(songs.last.id);
    expect([for (final s in request!.songs) s.title], ['Alpha', 'Bravo']);
    expect(request.index, 1);
  });

  test('songs without an artist are grouped as unknown', () async {
    final artists = await library.children(MediaIds.artists);
    final unknown = artists.firstWhere((a) => a.title == 'Unknown artist');
    final request = await library.resolve(MediaIds.song(unknown.id, 3));
    expect([for (final s in request!.songs) s.id], [3]);
  });

  test('album songs are in track order and albums carry artwork', () async {
    final albums = await library.children(MediaIds.albums);
    expect(albums.first.artUri.toString(), startsWith('content://'));
    final songs = await library.songsOf(MediaIds.album(10));
    expect([for (final s in songs!) s.id], [1, 2]);
  });

  test('playlists tab lists favorites then playlists', () async {
    final id = await db.createPlaylist('Drive');
    final songs = await db.songsByIds([3, 1]);
    await db.addToPlaylist(id, songs);
    await db.setFavorite(2, true);

    final items = await library.children(MediaIds.playlists);
    expect(ids(items), [MediaIds.favorites, MediaIds.playlist(id)]);
    final request = await library.resolve(
      MediaIds.song(MediaIds.playlist(id), 1),
    );
    expect([for (final s in request!.songs) s.id], [3, 1]);
    expect(request.index, 1);
  });

  test('search puts title matches before artist matches', () async {
    await db.replaceLibrary([
      _song(1, 'Bravo', artist: 'Charlie Band'),
      _song(2, 'Charlie'),
    ]);
    final results = await library.search('charlie');
    expect([for (final s in results) s.id], [2, 1]);
    final items = await library.searchItems('charlie');
    final request = await library.resolve(items.last.id);
    expect(request!.index, 1);
  });

  test('unknown ids resolve to nothing', () async {
    expect(await library.resolve('nonsense'), isNull);
    expect(await library.resolve(MediaIds.song(MediaIds.songs, 999)), isNull);
    expect(await library.children('playlist:abc'), isEmpty);
  });
}
