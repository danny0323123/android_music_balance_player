import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';

import '../data/database.dart';

/// 跟 Android 原生端（MediaChannel.kt）溝通：查詢 MediaStore、讀取專輯封面。
class MediaStoreChannel {
  static const _channel = MethodChannel('music_balance/media');

  static final _artFutures = <int, Future<String?>>{};
  static final _artResolved = <int, String?>{};

  static Future<int> sdkInt() async =>
      await _channel.invokeMethod<int>('sdkInt') ?? 0;

  static Future<List<SongsCompanion>> queryAudio() async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('queryAudio') ??
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
        ),
    ];
  }

  /// 專輯封面的快取檔案路徑，沒有封面時回傳 null。同一張專輯只會向原生端要一次。
  static Future<String?> albumArt(int albumId, int songId) {
    return _artFutures[albumId] ??= _channel
        .invokeMethod<String>('albumArt', {
          'albumId': albumId,
          'songId': songId,
          'size': 512,
        })
        .catchError((Object _) => null)
        .then((path) => _artResolved[albumId] = path);
  }

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
  static String? peekAlbumArt(int albumId) => _artResolved[albumId];
}
