import 'package:flutter/services.dart';

import '../data/database.dart';
import '../l10n/system_localizations.dart';

/// 把目前的歌和播放狀態送給桌面小工具（原生端 PlayerWidget.kt）。
abstract final class HomeWidget {
  static const _channel = MethodChannel('music_balance/widget');

  static Future<void> update(Song? song, {required bool playing}) async {
    try {
      await _channel.invokeMethod('update', {
        'title': song?.title,
        'subtitle': song == null
            ? null
            : song.artist ?? systemLocalizations().unknownArtist,
        'playing': playing,
        'albumId': song?.albumId,
        'songId': song?.id,
        'modified': song?.dateModified,
      });
    } on MissingPluginException {
      // 測試環境沒有原生端
    } on PlatformException {
      // 小工具更新失敗不影響播放
    }
  }
}
