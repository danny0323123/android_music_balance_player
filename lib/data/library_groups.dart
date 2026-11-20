import '../state/settings.dart';
import 'database.dart';

/// 音樂庫的過濾、排序、分組。介面（lib/state/library.dart）和 Android Auto 的瀏覽目錄共用。

bool isFolderExcluded(String folder, Set<String> excluded) =>
    excluded.any((e) => folder == e || folder.startsWith('$e/'));

int compareText(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

/// 套用排除規則（太短的音檔、排除的資料夾）。
List<Song> filterLibrary(List<Song> all, AppSettings settings) {
  final minMs = settings.minDurationSec * 1000;
  return [
    for (final song in all)
      if (song.durationMs >= minMs &&
          !isFolderExcluded(song.folder, settings.excludedFolders))
        song,
  ];
}

/// 依照使用者在「歌曲」分頁選的方式排序。
List<Song> sortSongs(List<Song> songs, AppSettings settings) {
  int byTitle(Song a, Song b) => compareText(a.title, b.title);
  final Comparator<Song> compare = switch (settings.songSort) {
    SongSort.title => byTitle,
    SongSort.artist => (a, b) {
      final c = compareText(a.artist ?? '', b.artist ?? '');
      return c != 0 ? c : byTitle(a, b);
    },
    SongSort.album => (a, b) {
      final c = compareText(a.album ?? '', b.album ?? '');
      return c != 0 ? c : a.trackNumber.compareTo(b.trackNumber);
    },
    SongSort.dateAdded => (a, b) => a.dateAdded.compareTo(b.dateAdded),
    SongSort.duration => (a, b) => a.durationMs.compareTo(b.durationMs),
  };
  return [...songs]
    ..sort(settings.sortAscending ? compare : (a, b) => compare(b, a));
}

/// 專輯依「專輯名稱 + 專輯演出者」分組：在 app 裡改了專輯名稱，歌就會歸到新的專輯。
/// 沒有專輯演出者的同名專輯會合併在一起。
class Album {
  Album(this.name, this.albumArtist, this.songs);
  final String? name;
  final String? albumArtist;
  final List<Song> songs;

  String get key => albumKey(songs.first);

  /// 專輯演出者，沒有的話用第一首歌的演出者。
  String? get artist => albumArtist ?? songs.first.artist;

  int? get year => songs.map((s) => s.year).nonNulls.firstOrNull;
}

String albumKey(Song s) => '${s.album ?? ''}\u0000${s.albumArtist ?? ''}';

class Artist {
  Artist(this.name, this.songs);
  final String? name;
  final List<Song> songs;
}

/// 有勾選的標籤：[matchAny] 為 false 時要全部都有，true 時有其中一個就好。
List<Song> filterByTags(
  List<Song> songs,
  Map<int, Set<int>> tagSongs,
  Set<int> selected, {
  required bool matchAny,
}) {
  if (selected.isEmpty) return const [];
  final sets = [for (final t in selected) tagSongs[t] ?? const <int>{}];
  bool has(Song s) => matchAny
      ? sets.any((ids) => ids.contains(s.id))
      : sets.every((ids) => ids.contains(s.id));
  return songs.where(has).toList();
}

class Folder {
  Folder(this.path, this.songs);
  final String path;
  final List<Song> songs;
  String get name => path.split('/').last;
}

int _byTrack(Song a, Song b) {
  final c = a.trackNumber.compareTo(b.trackNumber);
  return c != 0 ? c : compareText(a.title, b.title);
}

List<Album> groupAlbums(List<Song> songs) {
  final groups = <String, List<Song>>{};
  for (final s in songs) {
    groups.putIfAbsent(albumKey(s), () => []).add(s);
  }
  final albums = [
    for (final e in groups.values)
      Album(e.first.album, e.first.albumArtist, e..sort(_byTrack)),
  ];
  albums.sort((a, b) => compareText(a.name ?? '', b.name ?? ''));
  return albums;
}

List<Artist> groupArtists(List<Song> songs) {
  final groups = <String?, List<Song>>{};
  for (final s in songs) {
    groups.putIfAbsent(s.artist, () => []).add(s);
  }
  final artists = [
    for (final e in groups.entries)
      Artist(e.key, e.value..sort((a, b) => compareText(a.title, b.title))),
  ];
  artists.sort((a, b) => compareText(a.name ?? '', b.name ?? ''));
  return artists;
}

List<Folder> groupFolders(List<Song> songs) {
  final groups = <String, List<Song>>{};
  for (final s in songs) {
    groups.putIfAbsent(s.folder, () => []).add(s);
  }
  return [
    for (final e in groups.entries)
      Folder(e.key, e.value..sort((a, b) => compareText(a.title, b.title))),
  ]..sort((a, b) => compareText(a.path, b.path));
}
