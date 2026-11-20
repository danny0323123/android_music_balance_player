import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';

import '../data/database.dart';

/// 跟 Android 原生端（MediaChannel.kt）溝通：查詢 MediaStore、讀取專輯封面。
class MediaStoreChannel {
  static const _channel = MethodChannel('music_balance/media');

  static final _artFutures = <String, Future<String?>>{};
  static final _artResolved = <String, String?>{};

  static Future<int> sdkInt() async =>
      await _channel.invokeMethod<int>('sdkInt') ?? 0;

  /// [known]：已經算過指紋的歌（id → 當時的修改時間），沒改過的不重算指紋。
  static Future<List<SongsCompanion>> queryAudio(Map<int, int> known) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('queryAudio', {
          'known': known,
        }) ??
        const [];
    return [
      for (final r in rows)
        SongsCompanion.insert(
          id: Value((r['id'] as num).toInt()),
          uri: r['uri'] as String,
          path: r['path'] as String,
          folder: r['folder'] as String,
          title: r['title'] as String,
          artist: Value(r['artist'] as String?),
          album: Value(r['album'] as String?),
          albumId: (r['albumId'] as num).toInt(),
          durationMs: (r['duration'] as num).toInt(),
          trackNumber: (r['track'] as num).toInt(),
          dateAdded: (r['dateAdded'] as num).toInt(),
          dateModified: (r['dateModified'] as num).toInt(),
          albumArtist: Value(r['albumArtist'] as String?),
          genre: Value(r['genre'] as String?),
          year: Value((r['year'] as num?)?.toInt()),
          // 原生端這次有算指紋才更新，沒算的保留資料庫裡的
          fingerprint: r.containsKey('fingerprint')
              ? Value(r['fingerprint'] as String?)
              : const Value.absent(),
          fingerprintModified: r.containsKey('fingerprint')
              ? Value((r['dateModified'] as num).toInt())
              : const Value.absent(),
        ),
    ];
  }

  /// 歌曲封面的快取檔案路徑，沒有封面時回傳 null。檔案改過（例如換了封面）會重新讀取。
  static Future<String?> albumArt(Song song) {
    final key = _artKey(song);
    return _artFutures[key] ??= _channel
        .invokeMethod<String>('albumArt', {
          'albumId': song.albumId,
          'songId': song.id,
          'modified': song.dateModified,
          'size': 512,
        })
        .catchError((Object _) => null)
        .then((path) => _artResolved[key] = path);
  }

  static String _artKey(Song song) => '${song.id}-${song.dateModified}';

  /// 把標籤寫進檔案（[fields] 只放要改的，空字串表示清除），[artPath] 不為 null 時換封面。
  /// 回傳寫入失敗的檔案路徑。
  static Future<List<String>> writeTags(
    List<String> paths,
    Map<String, String> fields, {
    String? artPath,
  }) async =>
      await _channel.invokeListMethod<String>('writeTags', {
        'paths': paths,
        'fields': fields,
        'artPath': artPath,
      }) ??
      const [];

  /// 回傳刪除失敗的檔案路徑。
  static Future<List<String>> deleteFiles(List<String> paths) async =>
      await _channel.invokeListMethod<String>('deleteFiles', {
        'paths': paths,
      }) ??
      const [];

  /// 計算整首歌的響度（LUFS）。無法解碼時回傳 null 或拋出 [PlatformException]；
  /// 原生端沒有註冊（例如畫面還沒開過）時拋出 [MissingPluginException]。
  /// [priority] 為 true 時走原生端的專用執行緒，不用排在背景分析後面。
  static Future<double?> analyzeLoudness(
    String uri, {
    bool priority = false,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'analyzeLoudness',
      {'uri': uri, 'priority': priority},
    );
    return (result?['lufs'] as num?)?.toDouble();
  }

  /// 已經載入過的封面可以同步取得，避免清單捲動時閃爍。
  static String? peekAlbumArt(Song song) => _artResolved[_artKey(song)];
}
