import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../l10n/system_localizations.dart';
import '../platform/home_widget.dart';
import '../platform/media_store.dart';
import '../state/settings.dart';
import 'effects.dart';
import 'loudness.dart';
import 'media_library.dart';
import 'play_queue.dart';

enum NormalizationStatus { off, analyzing, applied, failed }

/// 目前這首歌的音量均衡狀態，給播放畫面顯示。
class NormalizationInfo {
  const NormalizationInfo(this.status, [this.gainDb = 0]);
  static const off = NormalizationInfo(NormalizationStatus.off);

  final NormalizationStatus status;
  final double gainDb;
}

class QueueState {
  const QueueState(this.songs, this.index, {this.shuffled = false});
  static const empty = QueueState([], -1);

  final List<Song> songs;
  final int index;
  final bool shuffled;

  Song? get current => index >= 0 && index < songs.length ? songs[index] : null;
}

/// 播放核心：自己管理播放佇列（[PlayQueue]），播放器一次只載入一首歌。
/// 佇列不透過 audio_service 的 queue 傳給系統，避免歌曲很多時超過 Android 的傳輸上限。
class PlayerHandler extends BaseAudioHandler with SeekHandler {
  PlayerHandler(this._db, this._prefs, this._loudness)
    : _library = MediaLibrary(_db, _prefs) {
    _ready = _init().onError(
      (Object e, StackTrace st) => Zone.current.handleUncaughtError(e, st),
    );
  }

  /// 啟動完成（包含還原上次的佇列）。Android Auto 或桌面小工具冷啟動時，
  /// 指令可能比還原先到：要等還原完，播放才有東西播，也不會被還原的佇列蓋掉。
  late final Future<void> _ready;

  static const _kQueue = 'player.queue';
  static const _kOriginalQueue = 'player.originalQueue';
  static const _kIndex = 'player.index';
  static const _kPosition = 'player.position';
  static const _kRepeat = 'player.repeat';

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final LoudnessService _loudness;
  final MediaLibrary _library;

  final _player = AudioPlayer(handleInterruptions: false);

  /// 播放器的 audio session，上面掛著 DynamicsProcessing（音量均衡、等化器、開車模式）。
  int? _session;

  /// 音效掛成功的話，音量均衡（放大和縮小）都由 DynamicsProcessing 處理；
  /// 手機不支援時退回用播放器音量，只能縮小不能放大。
  bool _effectsAttached = false;

  final queueState = BehaviorSubject<QueueState>.seeded(QueueState.empty);
  final normalization = BehaviorSubject<NormalizationInfo>.seeded(
    NormalizationInfo.off,
  );

  final _queue = PlayQueue();
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  int _loadFailures = 0;

  double _duckVolume = 1.0;
  Timer? _duckFade;
  bool _resumeAfterInterruption = false;

  /// 目前套用的音量均衡增益（dB）。
  double _gainDb = 0;
  Timer? _gainFade;

  /// 每次切歌或重新套用都會加一，讓過時的非同步分析結果被忽略。
  int _normalizationToken = 0;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Song? get currentSong => queueState.value.current;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen(_onInterruption);
    session.becomingNoisyEventStream.listen((_) => pause());

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e, StackTrace st) => _broadcastState(),
    );
    _player.playingStream.listen((_) => _broadcastState());
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onCompleted();
    });
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.playing) _savePosition();
    });

    // 桌面小工具跟著目前的歌和播放狀態更新
    Rx.combineLatest2(
      queueState.map((q) => q.current),
      playbackState.map((s) => s.playing),
      (Song? song, bool playing) => (song, playing),
    ).distinct().listen((s) => HomeWidget.update(s.$1, playing: s.$2));

    // 等化器、開車模式是原生端的全域設定，之後掛上的 session 都會套用
    await EffectsChannel.setEqualizer(
      _prefs.getBool(SettingsKeys.eqEnabled) ?? false,
      eqGainsFromPrefs(_prefs),
    );
    await EffectsChannel.setDrivingMode(
      _prefs.getBool(SettingsKeys.drivingMode) ?? false,
    );
    _player.androidAudioSessionIdStream.listen(_onAudioSession);

    await _restoreState();
  }

  Future<void> _onAudioSession(int? session) async {
    if (session == null || session == _session) return;
    final old = _session;
    _session = session;
    if (old != null) await EffectsChannel.release(old);
    _effectsAttached = await EffectsChannel.attach(session);
    if (_session != session) return; // 期間又換了 session
    _applyVolume();
    _applyEffectGain();
  }

  // ---------- 佇列操作（給介面呼叫） ----------

  /// 從 [index] 那首開始播放。隨機模式開著的話，其餘的歌會打亂順序。
  Future<void> playSongs(List<Song> songs, int index) async {
    await _ready;
    if (songs.isEmpty) return;
    _queue.setSongs(songs, index, shuffle: _queue.shuffled);
    await _load(_queue.index, play: true);
  }

  /// 「隨機播放」按鈕：打開隨機模式，產生一份打亂的暫時佇列並開始播放。
  Future<void> playShuffled(List<Song> songs) async {
    await _ready;
    if (songs.isEmpty) return;
    _queue.setSongsShuffled(songs);
    await _load(_queue.index, play: true);
  }

  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) return playSongs([song], 0);
    _queue.insertNext(song);
    _publishQueue();
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) return playSongs([song], 0);
    _queue.add(song);
    _publishQueue();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final wasCurrent = _queue.removeAt(index);
    if (_queue.isEmpty) {
      await _player.stop();
      mediaItem.add(null);
      _publishQueue();
      _broadcastState();
    } else if (wasCurrent) {
      await _load(_queue.index, play: _player.playing);
    } else {
      _publishQueue();
    }
  }

  /// [to] 是移除 [from] 之後要插入的位置。
  void moveQueueItem(int from, int to) {
    _queue.move(from, to);
    _publishQueue();
  }

  // ---------- audio_service 的控制介面（通知欄、耳機按鍵、鎖定畫面） ----------

  @override
  Future<void> play() async {
    await _ready;
    if (_queue.isEmpty) return;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _resumeAfterInterruption = false;
    await _player.pause();
    _savePosition();
  }

  @override
  Future<void> stop() async {
    _savePosition();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _load(index, play: true);
  }

  @override
  Future<void> skipToNext() async {
    await _ready;
    if (_queue.isEmpty) return;
    await _load((_queue.index + 1) % _queue.length, play: true);
  }

  @override
  Future<void> skipToPrevious() async {
    await _ready;
    if (_queue.isEmpty) return;
    if (_player.position > const Duration(seconds: 3) ||
        _queue.index == 0 && _repeatMode != AudioServiceRepeatMode.all) {
      await _player.seek(Duration.zero);
      return;
    }
    await _load((_queue.index - 1 + _queue.length) % _queue.length, play: true);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _queue.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
    _publishQueue();
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode == AudioServiceRepeatMode.group
        ? AudioServiceRepeatMode.all
        : repeatMode;
    await _player.setLoopMode(
      _repeatMode == AudioServiceRepeatMode.one ? LoopMode.one : LoopMode.off,
    );
    _prefs.setInt(_kRepeat, _repeatMode.index);
    _broadcastState();
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) await stop();
  }

  // ---------- Android Auto：瀏覽、搜尋、語音點歌 ----------

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    // 「最近播放」：Auto 開機時用來顯示可以繼續播的歌
    if (parentMediaId == AudioService.recentRootId) {
      await _ready;
      final song = currentSong;
      return song == null
          ? const []
          : [
              _library.songItem(
                song,
                AudioService.recentRootId,
                systemLocalizations(),
              ),
            ];
    }
    return _library.children(parentMediaId);
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) => _library.searchItems(query);

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    if (mediaId.startsWith('${AudioService.recentRootId}|')) return play();
    final request = await _library.resolve(mediaId);
    if (request == null) return;
    if (request.shuffle) {
      await playShuffled(request.songs);
    } else {
      await playSongs(request.songs, request.index);
    }
  }

  /// 「用均衡播放器播放 ○○○」。沒說要播什麼時繼續播放，佇列是空的就隨機播放全部。
  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    await _ready;
    if (query.trim().isEmpty) {
      if (!_queue.isEmpty) return play();
      return playShuffled(await _library.songsOf(MediaIds.songs) ?? const []);
    }
    final results = await _library.search(query);
    if (results.isNotEmpty) await playSongs(results, 0);
  }

  // ---------- 內部 ----------

  Future<void> _load(
    int index, {
    required bool play,
    Duration position = Duration.zero,
  }) async {
    _queue.index = index;
    final song = _queue.current!;
    _publishQueue();
    mediaItem.add(_toMediaItem(song));
    _loadArt(song);
    _applyNormalization(song, smooth: false);
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(song.uri)),
        initialPosition: position,
      );
    } on PlayerInterruptedException {
      return; // 被下一次切歌取代
    } catch (_) {
      // 檔案讀不到或格式不支援：自動跳下一首，整個佇列都失敗就停下來
      _loadFailures++;
      if (play && _loadFailures < _queue.length) {
        await _load((index + 1) % _queue.length, play: true);
      } else {
        _loadFailures = 0;
      }
      return;
    }
    _loadFailures = 0;
    if (play) unawaited(_player.play());

    // 先分析下一首，切歌時就不用再等
    final next = _queue.index + 1 < _queue.length
        ? _queue.songs[_queue.index + 1]
        : null;
    if (next != null && !_loudness.isAnalyzed(next)) {
      unawaited(
        _loudness.analyze(next, priority: true).catchError((_) => null),
      );
    }
  }

  void _onCompleted() {
    if (_queue.index + 1 < _queue.length) {
      _load(_queue.index + 1, play: true);
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      _load(0, play: true);
    } else {
      // 整個佇列播完：回到第一首並停住
      _player.pause();
      _load(0, play: false);
    }
  }

  Future<void> _loadArt(Song song) async {
    final path = await MediaStoreChannel.albumArt(song.albumId, song.id);
    if (path != null && currentSong?.id == song.id) {
      mediaItem.add(_toMediaItem(song, artPath: path));
    }
  }

  MediaItem _toMediaItem(Song song, {String? artPath}) => MediaItem(
    id: song.uri,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: Duration(milliseconds: song.durationMs),
    artUri: artPath == null ? null : Uri.file(artPath),
    extras: {'songId': song.id},
  );

  void _publishQueue() {
    final songs = List<Song>.unmodifiable(_queue.songs);
    queueState.add(QueueState(songs, _queue.index, shuffled: _queue.shuffled));
    _prefs.setStringList(_kQueue, [for (final s in songs) '${s.id}']);
    _prefs.setInt(_kIndex, _queue.index);
    final original = _queue.originalSongs;
    if (original == null) {
      _prefs.remove(_kOriginalQueue);
    } else {
      _prefs.setStringList(_kOriginalQueue, [
        for (final s in original) '${s.id}',
      ]);
    }
  }

  void _savePosition() =>
      _prefs.setInt(_kPosition, _player.position.inMilliseconds);

  Future<void> _restoreState() async {
    final repeat = _prefs.getInt(_kRepeat) ?? 0;
    await setRepeatMode(AudioServiceRepeatMode.values[repeat]);

    List<int> ids(String key) => (_prefs.getStringList(key) ?? const [])
        .map(int.tryParse)
        .nonNulls
        .toList();
    final songs = await _db.songsByIds(ids(_kQueue));
    if (songs.isEmpty) return;
    final original = _prefs.containsKey(_kOriginalQueue)
        ? await _db.songsByIds(ids(_kOriginalQueue))
        : null;
    _queue.restore(songs, _prefs.getInt(_kIndex) ?? 0, original);
    await _load(
      _queue.index,
      play: false,
      position: Duration(milliseconds: _prefs.getInt(_kPosition) ?? 0),
    );
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        // Android Auto 要看到 playFromMediaId 才能點清單裡的歌
        systemActions: const {
          MediaAction.seek,
          MediaAction.playFromMediaId,
          MediaAction.playFromSearch,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _queue.isEmpty
            ? AudioProcessingState.idle
            : const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _queue.isEmpty ? null : _queue.index,
        repeatMode: _repeatMode,
        shuffleMode: _queue.shuffled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  // ---------- 音訊焦點：導航降音、來電暫停 ----------

  void _onInterruption(AudioInterruptionEvent event) {
    final pauseOnDuck = _prefs.getBool(SettingsKeys.pauseOnDuck) ?? false;
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck when !pauseOnDuck:
          _fadeDuckVolume(
            _prefs.getDouble(SettingsKeys.duckLevel) ??
                AppSettings.defaultDuckLevel,
          );
        case AudioInterruptionType.duck:
        case AudioInterruptionType.pause:
          if (_player.playing) {
            _resumeAfterInterruption = true;
            _player.pause();
          }
        case AudioInterruptionType.unknown:
          // 其他 app 要長期播放（例如打開別的音樂 app），暫停且不自動恢復
          _resumeAfterInterruption = false;
          _player.pause();
      }
    } else {
      _fadeDuckVolume(1.0);
      if (_resumeAfterInterruption &&
          event.type != AudioInterruptionType.unknown) {
        _player.play();
      }
      _resumeAfterInterruption = false;
    }
  }

  void _fadeDuckVolume(double target) {
    _duckFade?.cancel();
    final start = _duckVolume;
    const steps = 10;
    var step = 0;
    _duckFade = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      step++;
      _duckVolume = start + (target - start) * step / steps;
      _applyVolume();
      if (step >= steps) timer.cancel();
    });
  }

  // ---------- 音量均衡 ----------

  /// 設定改變時（開關、目標響度）重新套用到目前這首。
  void refreshNormalization() {
    final song = _queue.current;
    if (song != null) _applyNormalization(song, smooth: true);
  }

  /// 套用 [song] 的音量均衡增益。
  ///
  /// 已分析過的歌直接套用。還沒分析的歌先用音樂庫的典型響度估計，
  /// 同時插隊分析，分析完再平滑地調到正確的增益。
  void _applyNormalization(Song song, {required bool smooth}) {
    final token = ++_normalizationToken;
    void setGain(double db) => smooth ? _fadeGain(db) : _setGain(db);

    if (!(_prefs.getBool(SettingsKeys.normalizeEnabled) ?? true)) {
      setGain(0);
      normalization.add(NormalizationInfo.off);
      return;
    }
    final target =
        _prefs.getDouble(SettingsKeys.normalizeTarget) ?? defaultTargetLufs;

    if (_loudness.isAnalyzed(song)) {
      final lufs = _loudness.knownLufs(song);
      if (lufs == null) {
        setGain(0);
        normalization.add(const NormalizationInfo(NormalizationStatus.failed));
      } else {
        final gain = normalizationGainDb(lufs, target);
        setGain(gain);
        normalization.add(NormalizationInfo(NormalizationStatus.applied, gain));
      }
      return;
    }

    final typical = _loudness.typicalLufs;
    setGain(typical == null ? 0 : normalizationGainDb(typical, target));
    normalization.add(const NormalizationInfo(NormalizationStatus.analyzing));
    _loudness
        .analyze(song, priority: true)
        .then((lufs) {
          if (token != _normalizationToken) return; // 已經切到別首
          if (lufs == null) {
            // 無法分析：維持估計值，總比突然變回原始音量好
            normalization.add(
              const NormalizationInfo(NormalizationStatus.failed),
            );
            return;
          }
          final gain = normalizationGainDb(lufs, target);
          _fadeGain(gain);
          normalization.add(
            NormalizationInfo(NormalizationStatus.applied, gain),
          );
        })
        .catchError((Object _) {
          // 原生端還沒準備好（畫面沒開過），之後切歌時會再試
        });
  }

  void _setGain(double db) {
    _gainFade?.cancel();
    _gainDb = db;
    _applyVolume();
    _applyEffectGain();
  }

  /// 在約 0.8 秒內平滑地調到 [target]，避免音量突然跳動。
  void _fadeGain(double target) {
    _gainFade?.cancel();
    final start = _gainDb;
    const steps = 16;
    var step = 0;
    _gainFade = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      _gainDb = start + (target - start) * step / steps;
      _applyVolume();
      // 增益透過平台呼叫設定，不用每一步都更新
      if (step.isEven || step >= steps) _applyEffectGain();
      if (step >= steps) timer.cancel();
    });
  }

  void _applyEffectGain() {
    final session = _session;
    if (session != null && _effectsAttached) {
      EffectsChannel.setGain(session, _gainDb);
    }
  }

  /// 播放器音量 = 導航降音比例。音量均衡的增益在 DynamicsProcessing 裡處理；
  /// 手機不支援音效時，才用播放器音量做縮小（放大就沒辦法了）。
  void _applyVolume() {
    final cut = !_effectsAttached && _gainDb < 0
        ? pow(10, _gainDb / 20).toDouble()
        : 1.0;
    _player.setVolume(_duckVolume * cut);
  }
}
