import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/effects.dart';
import '../audio/loudness.dart';
import 'player.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

enum SongSort { title, artist, album, dateAdded, duration }

/// SharedPreferences 的 key。播放器（PlayerHandler）也會直接讀取其中幾個。
abstract final class SettingsKeys {
  static const themeMode = 'themeMode';
  static const minDurationSec = 'minDurationSec';
  static const excludedFolders = 'excludedFolders';
  static const songSort = 'songSort';
  static const sortAscending = 'sortAscending';
  static const duckLevel = 'duckLevel';
  static const pauseOnDuck = 'pauseOnDuck';
  static const normalizeEnabled = 'normalizeEnabled';
  static const normalizeTarget = 'normalizeTarget';
  static const eqEnabled = 'eqEnabled';
  static const eqGains = 'eqGains';
  static const drivingMode = 'drivingMode';
}

/// 等化器各段增益（dB）。存成字串清單，長度不對（例如舊版資料）時回到平坦。
List<double> eqGainsFromPrefs(SharedPreferences p) {
  final stored = p.getStringList(SettingsKeys.eqGains);
  final gains = stored?.map(double.tryParse).nonNulls.toList();
  return gains != null && gains.length == eqFrequencies.length
      ? gains
      : EqPreset.flat.gains;
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.minDurationSec,
    required this.excludedFolders,
    required this.songSort,
    required this.sortAscending,
    required this.duckLevel,
    required this.pauseOnDuck,
    required this.normalizeEnabled,
    required this.normalizeTarget,
    required this.eqEnabled,
    required this.eqGains,
    required this.drivingMode,
  });

  factory AppSettings.fromPrefs(SharedPreferences p) => AppSettings(
    themeMode: ThemeMode.values[p.getInt(SettingsKeys.themeMode) ?? 0],
    minDurationSec:
        p.getInt(SettingsKeys.minDurationSec) ??
        AppSettings.defaultMinDurationSec,
    excludedFolders: (p.getStringList(SettingsKeys.excludedFolders) ?? const [])
        .toSet(),
    songSort: SongSort.values[p.getInt(SettingsKeys.songSort) ?? 0],
    sortAscending: p.getBool(SettingsKeys.sortAscending) ?? true,
    duckLevel:
        p.getDouble(SettingsKeys.duckLevel) ?? AppSettings.defaultDuckLevel,
    pauseOnDuck: p.getBool(SettingsKeys.pauseOnDuck) ?? false,
    normalizeEnabled: p.getBool(SettingsKeys.normalizeEnabled) ?? true,
    normalizeTarget:
        p.getDouble(SettingsKeys.normalizeTarget) ?? defaultTargetLufs,
    eqEnabled: p.getBool(SettingsKeys.eqEnabled) ?? false,
    eqGains: eqGainsFromPrefs(p),
    drivingMode: p.getBool(SettingsKeys.drivingMode) ?? false,
  );

  static const defaultMinDurationSec = 30;
  static const defaultDuckLevel = 0.2;

  final ThemeMode themeMode;
  final int minDurationSec;
  final Set<String> excludedFolders;
  final SongSort songSort;
  final bool sortAscending;

  /// 導航說話時，音樂保留的音量比例（0.1 ~ 0.5）。
  final double duckLevel;
  final bool pauseOnDuck;

  /// 音量均衡：讓每首歌都調整到 [normalizeTarget]（LUFS）。
  final bool normalizeEnabled;
  final double normalizeTarget;

  final bool eqEnabled;
  final List<double> eqGains;

  /// 開車模式：壓縮歌曲內的大小聲差距。
  final bool drivingMode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? minDurationSec,
    Set<String>? excludedFolders,
    SongSort? songSort,
    bool? sortAscending,
    double? duckLevel,
    bool? pauseOnDuck,
    bool? normalizeEnabled,
    double? normalizeTarget,
    bool? eqEnabled,
    List<double>? eqGains,
    bool? drivingMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      minDurationSec: minDurationSec ?? this.minDurationSec,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      songSort: songSort ?? this.songSort,
      sortAscending: sortAscending ?? this.sortAscending,
      duckLevel: duckLevel ?? this.duckLevel,
      pauseOnDuck: pauseOnDuck ?? this.pauseOnDuck,
      normalizeEnabled: normalizeEnabled ?? this.normalizeEnabled,
      normalizeTarget: normalizeTarget ?? this.normalizeTarget,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqGains: eqGains ?? this.eqGains,
      drivingMode: drivingMode ?? this.drivingMode,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() => AppSettings.fromPrefs(ref.watch(prefsProvider));

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt(SettingsKeys.themeMode, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  void setMinDuration(int seconds) {
    _prefs.setInt(SettingsKeys.minDurationSec, seconds);
    state = state.copyWith(minDurationSec: seconds);
  }

  void setFolderExcluded(String folder, bool excluded) {
    final folders = {...state.excludedFolders};
    excluded ? folders.add(folder) : folders.remove(folder);
    _prefs.setStringList(SettingsKeys.excludedFolders, folders.toList());
    state = state.copyWith(excludedFolders: folders);
  }

  void setSongSort(SongSort sort) {
    _prefs.setInt(SettingsKeys.songSort, sort.index);
    state = state.copyWith(songSort: sort);
  }

  void setSortAscending(bool ascending) {
    _prefs.setBool(SettingsKeys.sortAscending, ascending);
    state = state.copyWith(sortAscending: ascending);
  }

  void setDuckLevel(double level) {
    _prefs.setDouble(SettingsKeys.duckLevel, level);
    state = state.copyWith(duckLevel: level);
  }

  void setPauseOnDuck(bool value) {
    _prefs.setBool(SettingsKeys.pauseOnDuck, value);
    state = state.copyWith(pauseOnDuck: value);
  }

  // 音量均衡的設定改了，正在播放的歌要馬上重新套用

  Future<void> setNormalizeEnabled(bool value) async {
    await _prefs.setBool(SettingsKeys.normalizeEnabled, value);
    state = state.copyWith(normalizeEnabled: value);
    ref.read(playerProvider).refreshNormalization();
  }

  Future<void> setNormalizeTarget(double lufs) async {
    await _prefs.setDouble(SettingsKeys.normalizeTarget, lufs);
    state = state.copyWith(normalizeTarget: lufs);
    ref.read(playerProvider).refreshNormalization();
  }

  // 等化器和開車模式是原生端的全域設定，改了直接送過去

  void setEqEnabled(bool enabled) {
    _prefs.setBool(SettingsKeys.eqEnabled, enabled);
    state = state.copyWith(eqEnabled: enabled);
    EffectsChannel.setEqualizer(enabled, state.eqGains);
  }

  void setEqGains(List<double> gains) {
    _prefs.setStringList(SettingsKeys.eqGains, [for (final g in gains) '$g']);
    state = state.copyWith(eqGains: List.unmodifiable(gains));
    EffectsChannel.setEqualizer(state.eqEnabled, gains);
  }

  void setEqBand(int band, double gainDb) =>
      setEqGains([...state.eqGains]..[band] = gainDb);

  void setDrivingMode(bool enabled) {
    _prefs.setBool(SettingsKeys.drivingMode, enabled);
    state = state.copyWith(drivingMode: enabled);
    EffectsChannel.setDrivingMode(enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
