import 'package:flutter/services.dart';

/// 10 段等化器的中心頻率（Hz），和原生端 AudioEffectsChannel.EQ_CUTOFFS 對應。
const eqFrequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

/// 每段可調整的範圍（dB）。
const eqMaxGainDb = 12.0;

enum EqPreset {
  flat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  bassBoost([6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
  trebleBoost([0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
  vocal([-2, -2, -1, 0, 2, 4, 4, 2, 0, -1]),
  rock([4, 3, 2, 0, -1, -1, 1, 2, 3, 4]),
  pop([-1, 0, 2, 3, 3, 2, 0, -1, -1, -1]),
  classical([3, 2, 1, 0, 0, 0, -1, -1, 1, 2]);

  const EqPreset(this.gains);
  final List<double> gains;

  /// 目前的設定符合哪個預設；自訂的話回傳 null。
  static EqPreset? matching(List<double> gains) {
    for (final preset in values) {
      var same = preset.gains.length == gains.length;
      for (var i = 0; same && i < gains.length; i++) {
        same = (preset.gains[i] - gains[i]).abs() < 0.05;
      }
      if (same) return preset;
    }
    return null;
  }
}

/// 跟原生端（AudioEffectsChannel.kt）溝通。每個播放器 session 掛一個 DynamicsProcessing：
/// 輸入增益（音量均衡）→ 等化器 → 壓縮器（開車模式）→ 限幅器。
///
/// 原生端沒註冊（例如 App 畫面沒開過）或手機不支援時，所有呼叫都安靜地失敗。
abstract final class EffectsChannel {
  static const _channel = MethodChannel('music_balance/effects');

  static Future<T?> _call<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 回傳是否成功掛上音效；失敗時音量均衡只能用播放器音量做「縮小」。
  static Future<bool> attach(int session) async =>
      await _call<bool>('attach', {'session': session}) ?? false;

  static Future<void> release(int session) =>
      _call<void>('release', {'session': session});

  static Future<void> setGain(int session, double db) =>
      _call<void>('setGain', {'session': session, 'db': db});

  static Future<void> setEqualizer(bool enabled, List<double> gains) =>
      _call<void>('setEqualizer', {'enabled': enabled, 'gains': gains});

  static Future<void> setDrivingMode(bool enabled) =>
      _call<void>('setDrivingMode', {'enabled': enabled});
}
