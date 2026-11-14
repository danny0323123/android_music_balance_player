import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import '../data/database.dart';
import '../platform/media_store.dart';

/// 放大最多 +10 dB（LoudnessEnhancer 會壓縮避免破音，但放太多會聽得出被壓扁）。
const maxBoostDb = 10.0;

/// 縮小最多 -20 dB。
const maxCutDb = 20.0;

const defaultTargetLufs = -14.0;

/// 背景同時分析的歌數，要和原生端 MediaChannel.ANALYSIS_THREADS 一致。
const backgroundWorkers = 3;

/// 播放時要套用的增益（dB）：目標響度 − 這首歌的響度。
double normalizationGainDb(double lufs, double targetLufs) =>
    (targetLufs - lufs).clamp(-maxCutDb, maxBoostDb);

/// 中位數；空的時候回傳 null。
double? median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return null;
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

class _Known {
  const _Known(this.lufs, this.modified);
  final double? lufs;
  final int modified;
}

/// 管理每首歌的響度分析：背景依序分析整個音樂庫，正在播放的歌可以插隊。
class LoudnessService {
  LoudnessService(this._db);

  final AppDatabase _db;

  /// 已分析的結果（含分析失敗的 null），key 是歌曲 id。
  final _known = <int, _Known>{};
  final _inFlight = <int, Future<double?>>{};
  double? _typical;
  bool _typicalDirty = true;

  bool _looping = false;
  bool _loopAgain = false;

  /// 「重新分析全部」之後，佇列裡舊的 Song 物件還帶著舊結果，不能再相信。
  bool _trustSongFields = true;

  /// 背景分析是否正在進行。
  final running = BehaviorSubject<bool>.seeded(false);

  Future<void> init() async {
    for (final s in await _db.select(_db.songs).get()) {
      final modified = s.analyzedModified;
      if (modified != null) _known[s.id] = _Known(s.lufs, modified);
    }
    _typicalDirty = true;
  }

  bool _songFieldsValid(Song song) =>
      _trustSongFields && song.analyzedModified == song.dateModified;

  bool isAnalyzed(Song song) =>
      _known[song.id]?.modified == song.dateModified || _songFieldsValid(song);

  /// 已分析的響度；還沒分析或分析失敗時回傳 null。
  double? knownLufs(Song song) {
    final known = _known[song.id];
    if (known != null && known.modified == song.dateModified) {
      return known.lufs;
    }
    return _songFieldsValid(song) ? song.lufs : null;
  }

  /// 音樂庫的典型響度（已分析歌曲的中位數），給還沒分析的歌當作暫時的估計。
  double? get typicalLufs {
    if (_typicalDirty) {
      _typical = median(_known.values.map((k) => k.lufs).nonNulls);
      _typicalDirty = false;
    }
    return _typical;
  }

  /// 分析一首歌（已在分析中的不會重複分析），回傳響度。
  /// [priority]：正在播放或下一首要播的歌，不用排在背景分析後面。
  Future<double?> analyze(Song song, {bool priority = false}) {
    if (isAnalyzed(song)) return Future.value(knownLufs(song));
    // 注意：callback 不能寫成 `() => _inFlight.remove(...)`，remove 會回傳這個
    // Future 本身，whenComplete 會等它完成 → 自己等自己，永遠不會結束
    return _inFlight[song.id] ??= _analyze(song, priority).whenComplete(() {
      _inFlight.remove(song.id);
    });
  }

  Future<double?> _analyze(Song song, bool priority) async {
    double? lufs;
    try {
      lufs = await MediaStoreChannel.analyzeLoudness(
        song.uri,
        priority: priority,
      );
    } on MissingPluginException {
      rethrow; // 原生端還沒準備好：不要把歌標記成失敗
    } on PlatformException {
      lufs = null; // 解碼失敗
    }
    await _db.saveLoudness(song, lufs);
    _known[song.id] = _Known(lufs, song.dateModified);
    _typicalDirty = true;
    return lufs;
  }

  /// 開始（或繼續）背景分析整個音樂庫。重複呼叫是安全的。
  Future<void> start() async {
    if (_looping) {
      _loopAgain = true;
      return;
    }
    _looping = true;
    running.add(true);
    try {
      do {
        _loopAgain = false;
        // 同時分析好幾首：每首的時間主要卡在 MediaCodec 呼叫的固定開銷，
        // 不是 CPU，平行處理可以快好幾倍（原生端也開了同樣數量的執行緒）
        final pending = (await _db.songsNeedingAnalysis()).iterator;
        Future<void> worker() async {
          while (pending.moveNext()) {
            final song = pending.current;
            if (!isAnalyzed(song)) await analyze(song);
          }
        }

        await Future.wait([
          for (var i = 0; i < backgroundWorkers; i++) worker(),
        ]);
      } while (_loopAgain);
    } on MissingPluginException {
      // 畫面開啟、原生端註冊之後會再被呼叫
    } finally {
      _looping = false;
      running.add(false);
    }
  }

  /// 清除所有分析結果並重新分析。
  Future<void> reanalyzeAll() async {
    await _db.resetLoudness();
    _known.clear();
    _trustSongFields = false;
    _typicalDirty = true;
    await start();
  }
}
