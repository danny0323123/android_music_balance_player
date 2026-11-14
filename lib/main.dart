import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'audio/loudness.dart';
import 'audio/media_library.dart';
import 'audio/player_handler.dart';
import 'data/database.dart';
import 'state/library.dart';
import 'state/loudness.dart';
import 'state/player.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  final loudness = LoudnessService(db);
  await loudness.init();
  final player = await AudioService.init(
    builder: () => PlayerHandler(db, prefs, loudness),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.musicbalance.music_balance.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidBrowsableRootExtras: MediaLibrary.rootExtras,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        playerProvider.overrideWithValue(player),
        loudnessProvider.overrideWithValue(loudness),
      ],
      child: const MusicApp(),
    ),
  );
}
