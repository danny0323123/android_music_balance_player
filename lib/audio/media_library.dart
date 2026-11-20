import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/library_groups.dart';
import '../l10n/app_localizations.dart';
import '../l10n/system_localizations.dart';
import '../state/settings.dart';

/// Android Auto 瀏覽目錄的項目 id。
///
/// 資料夾：`songs`、`playlists`、`playlist:3`、`album:12`、`artist:<編碼過的名字>`…
/// 歌曲：`<資料夾 id>|<歌曲 id>`，點下去會從那首開始播整個資料夾。
/// 隨機播放：`shuffle><資料夾 id>`。
abstract final class MediaIds {
  static const songs = 'songs';
  static const playlists = 'playlists';
  static const albums = 'albums';
  static const artists = 'artists';
  static const favorites = 'favorites';

  static String playlist(int id) => 'playlist:$id';
  static String tag(int id) => 'tag:$id';
  static String album(String key) => 'album:${Uri.encodeComponent(key)}';
  static String artist(String? name) =>
      'artist:${Uri.encodeComponent(name ?? '')}';
  static String search(String query) => 'search:${Uri.encodeComponent(query)}';
  static String song(String parent, int songId) => '$parent|$songId';
  static String shuffle(String parent) => '$_shufflePrefix$parent';

  static const _shufflePrefix = 'shuffle>';
}

/// Android Auto 點了某個項目後要播的內容。
class PlayRequest {
  const PlayRequest(this.songs, this.index, {this.shuffle = false});
  final List<Song> songs;
  final int index;
  final bool shuffle;
}

/// 給 Android Auto 瀏覽的音樂庫：歌曲、播放清單、專輯、歌手，和 app 的分頁一樣套用排除規則。
class MediaLibrary {
  MediaLibrary(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  /// 封面由原生端的 ArtProvider 提供，Android Auto 在別的程序也能讀。
  static const _artAuthority = 'com.musicbalance.music_balance.art';

  // Android Auto 的顯示方式：1 = 清單，2 = 格狀
  static const _browsableHint =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const _styleList = 1;
  static const _styleGrid = 2;

  /// 根目錄的設定：支援搜尋、預設用清單顯示。
  static const rootExtras = <String, dynamic>{
    'android.media.browse.SEARCH_SUPPORTED': true,
    'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
    _browsableHint: _styleList,
    'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': _styleList,
  };

  AppSettings get _settings => AppSettings.fromPrefs(_prefs);

  Future<List<Song>> _library() async =>
      filterLibrary(await _db.watchSongs().first, _settings);

  Future<List<MediaItem>> children(String parentId) async {
    final l10n = systemLocalizations();
    switch (parentId) {
      case AudioService.browsableRootId:
        // Android Auto 最多顯示 4 個分頁
        return [
          _folder(MediaIds.songs, l10n.tabSongs),
          _folder(MediaIds.playlists, l10n.tabPlaylists),
          _folder(MediaIds.albums, l10n.tabAlbums, childStyle: _styleGrid),
          _folder(MediaIds.artists, l10n.tabArtists),
        ];
      case MediaIds.playlists:
        // Android Auto 最多 4 個分頁，標籤放在播放清單後面
        final favorites = await _db.watchFavoriteSongs().first;
        final playlists = await _db.watchPlaylists().first;
        final tags = await _db.watchTags().first;
        return [
          _folder(
            MediaIds.favorites,
            l10n.favorites,
            subtitle: l10n.songCount(favorites.length),
          ),
          for (final p in playlists)
            _folder(
              MediaIds.playlist(p.playlist.id),
              p.playlist.name,
              subtitle: l10n.songCount(p.songCount),
            ),
          for (final t in tags)
            if (t.songCount > 0)
              _folder(
                MediaIds.tag(t.tag.id),
                '# ${t.tag.name}',
                subtitle: l10n.songCount(t.songCount),
              ),
        ];
      case MediaIds.albums:
        return [
          for (final a in groupAlbums(await _library()))
            _folder(
              MediaIds.album(a.key),
              a.name ?? l10n.unknownAlbum,
              subtitle: a.artist ?? l10n.unknownArtist,
              artUri: artUri(a.songs.first),
            ),
        ];
      case MediaIds.artists:
        return [
          for (final a in groupArtists(await _library()))
            _folder(
              MediaIds.artist(a.name),
              a.name ?? l10n.unknownArtist,
              subtitle: l10n.songCount(a.songs.length),
            ),
        ];
    }
    final songs = await songsOf(parentId);
    if (songs == null) return const [];
    return [
      if (songs.length > 1)
        MediaItem(
          id: MediaIds.shuffle(parentId),
          title: l10n.shuffle,
          artist: l10n.songCount(songs.length),
          playable: true,
        ),
      for (final s in songs) songItem(s, parentId, l10n),
    ];
  }

  /// 某個資料夾裡的歌，順序和 app 裡看到的一樣；不認得的 id 回傳 null。
  Future<List<Song>?> songsOf(String parentId) async {
    if (parentId == MediaIds.songs) {
      return sortSongs(await _library(), _settings);
    }
    if (parentId == MediaIds.favorites) {
      return _db.watchFavoriteSongs().first;
    }
    final colon = parentId.indexOf(':');
    if (colon < 0) return null;
    final key = parentId.substring(colon + 1);
    switch (parentId.substring(0, colon)) {
      case 'playlist':
        final id = int.tryParse(key);
        if (id == null) return null;
        final entries = await _db.watchPlaylistEntries(id).first;
        return [for (final e in entries) e.song];
      case 'tag':
        final id = int.tryParse(key);
        if (id == null) return null;
        final ids = (await _db.watchTagSongs().first)[id] ?? const {};
        return sortSongs([
          for (final s in await _library())
            if (ids.contains(s.id)) s,
        ], _settings);
      case 'album':
        final albumKey = Uri.decodeComponent(key);
        return groupAlbums(await _library())
            .where((a) => a.key == albumKey)
            .firstOrNull
            ?.songs;
      case 'artist':
        final name = Uri.decodeComponent(key);
        final songs = [
          for (final s in await _library())
            if ((s.artist ?? '') == name) s,
        ];
        return groupArtists(songs).firstOrNull?.songs;
      case 'search':
        return search(Uri.decodeComponent(key));
    }
    return null;
  }

  /// 歌名符合的排前面，接著是歌手或專輯符合的。
  Future<List<Song>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    bool has(String? text) => text != null && text.toLowerCase().contains(q);
    final library = await _library();
    return [
      ...library.where((s) => has(s.title)),
      ...library.where((s) => !has(s.title) && (has(s.artist) || has(s.album))),
    ];
  }

  Future<List<MediaItem>> searchItems(String query) async {
    final l10n = systemLocalizations();
    final parent = MediaIds.search(query);
    return [for (final s in await search(query)) songItem(s, parent, l10n)];
  }

  /// 把點下去的項目 id 轉成要播的歌。
  Future<PlayRequest?> resolve(String mediaId) async {
    if (mediaId.startsWith(MediaIds._shufflePrefix)) {
      final songs = await songsOf(
        mediaId.substring(MediaIds._shufflePrefix.length),
      );
      return songs == null || songs.isEmpty
          ? null
          : PlayRequest(songs, 0, shuffle: true);
    }
    final bar = mediaId.lastIndexOf('|');
    if (bar < 0) return null;
    final songId = int.tryParse(mediaId.substring(bar + 1));
    final songs = await songsOf(mediaId.substring(0, bar));
    if (songs == null) return null;
    final index = songs.indexWhere((s) => s.id == songId);
    return index < 0 ? null : PlayRequest(songs, index);
  }

  MediaItem songItem(Song song, String parent, AppLocalizations l10n) =>
      MediaItem(
        id: MediaIds.song(parent, song.id),
        title: song.title,
        artist: song.artist ?? l10n.unknownArtist,
        album: song.album,
        duration: Duration(milliseconds: song.durationMs),
        artUri: artUri(song),
        playable: true,
      );

  static Uri artUri(Song song) => Uri.parse(
    'content://$_artAuthority/${song.albumId}/${song.id}/${song.dateModified}',
  );

  MediaItem _folder(
    String id,
    String title, {
    String? subtitle,
    Uri? artUri,
    int? childStyle,
  }) => MediaItem(
    id: id,
    title: title,
    artist: subtitle,
    artUri: artUri,
    playable: false,
    extras: childStyle == null ? null : {_browsableHint: childStyle},
  );
}
