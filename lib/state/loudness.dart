import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/loudness.dart';
import '../audio/player_handler.dart';
import 'library.dart';
import 'player.dart';

final loudnessProvider = Provider<LoudnessService>(
  (ref) => throw UnimplementedError(),
);

final analysisRunningProvider = StreamProvider<bool>(
  (ref) => ref.watch(loudnessProvider).running,
);

/// （已分析的歌數，總歌數）。分析失敗的也算「已分析」，不會再重試。
final analysisProgressProvider = Provider<(int, int)>((ref) {
  final songs = ref.watch(allSongsProvider).value ?? const [];
  final done = songs.where((s) => s.analyzedModified == s.dateModified).length;
  return (done, songs.length);
});

final normalizationInfoProvider = StreamProvider<NormalizationInfo>(
  (ref) => ref.watch(playerProvider).normalization,
);
