import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_handler.dart';

final playerProvider = Provider<PlayerHandler>(
  (ref) => throw UnimplementedError(),
);

final queueStateProvider = StreamProvider<QueueState>(
  (ref) => ref.watch(playerProvider).queueState,
);

final currentSongIdProvider = Provider<int?>(
  (ref) => ref.watch(queueStateProvider).value?.current?.id,
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(playerProvider).playbackState,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playerProvider).positionStream,
);

final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(playerProvider).durationStream,
);
