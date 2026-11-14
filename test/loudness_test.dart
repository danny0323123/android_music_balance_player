import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/audio/loudness.dart';
import 'package:music_balance/data/database.dart';
import 'package:music_balance/ui/common.dart';

const _channel = MethodChannel('music_balance/media');

SongsCompanion _song(int id, {int modified = 1}) => SongsCompanion.insert(
  id: Value(id),
  uri: 'song://$id',
  path: '/Music/$id.mp3',
  folder: '/Music',
  title: 'Song $id',
  albumId: 1,
  durationMs: 180000,
  trackNumber: 0,
  dateAdded: id,
  dateModified: modified,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizationGainDb', () {
    test('is target minus song loudness', () {
      expect(normalizationGainDb(-8, -14), -6);
      expect(normalizationGainDb(-20, -14), 6);
    });

    test('is clamped so quiet songs are not boosted too much', () {
      expect(normalizationGainDb(-40, -14), maxBoostDb);
      expect(normalizationGainDb(20, -14), -maxCutDb);
    });
  });

  test('median', () {
    expect(median([]), isNull);
    expect(median([-10, -8, -20]), -10);
    expect(median([-10, -8, -20, -12]), -11);
  });

  test('formatGain uses a real minus sign and one decimal', () {
    expect(formatGain(-3.24), '−3.2 dB');
    expect(formatGain(4.06), '+4.1 dB');
    expect(formatGain(0.01), '0 dB');
  });

  group('LoudnessService', () {
    late AppDatabase db;
    late LoudnessService service;
    late Map<String, Object? Function()> responses;
    late List<String> calls;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.replaceLibrary([_song(1), _song(2), _song(3)]);
      service = LoudnessService(db);
      await service.init();
      calls = [];
      responses = {
        'song://1': () => {'lufs': -8.0, 'peakDb': -0.1},
        'song://2': () => {'lufs': -20.0, 'peakDb': -3.0},
        'song://3': () => {'lufs': -12.0, 'peakDb': -1.0},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            final uri = (call.arguments as Map)['uri'] as String;
            calls.add(uri);
            return responses[uri]!();
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      await db.close();
    });

    Future<Song> song(int id) =>
        (db.select(db.songs)..where((t) => t.id.equals(id))).getSingle();

    test('start analyzes every song and stores the result', () async {
      await service.start();
      expect(calls.toSet(), {'song://1', 'song://2', 'song://3'});
      expect((await song(2)).lufs, -20.0);
      expect(service.isAnalyzed(await song(1)), isTrue);
      expect(await db.songsNeedingAnalysis(), isEmpty);
      expect(service.typicalLufs, -12.0); // 中位數
    });

    test('newest songs are analyzed first', () async {
      await service.start();
      expect(calls, ['song://3', 'song://2', 'song://1']);
    });

    test('a song is not analyzed twice at the same time', () async {
      final s = await song(1);
      final results = await Future.wait([
        service.analyze(s),
        service.analyze(s),
      ]);
      expect(results, [-8.0, -8.0]);
      expect(calls, ['song://1']);
    });

    test('failed songs are remembered and not retried', () async {
      responses['song://2'] = () => throw PlatformException(code: 'ERR');
      await service.start();
      final failed = await song(2);
      expect(failed.lufs, isNull);
      expect(service.isAnalyzed(failed), isTrue);
      expect(service.knownLufs(failed), isNull);

      calls.clear();
      await service.start();
      expect(calls, isEmpty);
    });

    test('a modified file is analyzed again', () async {
      await service.start();
      await db.replaceLibrary([_song(1, modified: 2), _song(2), _song(3)]);
      final modified = await song(1);
      expect(service.isAnalyzed(modified), isFalse);
      expect((await db.songsNeedingAnalysis()).map((s) => s.id), [1]);
    });

    test('missing native side does not mark songs as failed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      await service.start();
      expect(await db.songsNeedingAnalysis(), hasLength(3));
      expect(service.running.value, isFalse);
    });

    test('init restores results saved by a previous session', () async {
      await service.start();
      final fresh = LoudnessService(db);
      await fresh.init();
      // 用分析前的舊 Song 物件也查得到（結果來自資料庫）
      final stale = Song(
        id: 2,
        uri: 'song://2',
        path: '/Music/2.mp3',
        folder: '/Music',
        title: 'Song 2',
        albumId: 1,
        durationMs: 180000,
        trackNumber: 0,
        dateAdded: 2,
        dateModified: 1,
      );
      expect(fresh.knownLufs(stale), -20.0);
    });

    test('reanalyzeAll ignores stale results on queued songs', () async {
      await service.start();
      final queued = await song(1); // 播放佇列裡的舊物件，帶著舊結果
      responses['song://1'] = () => {'lufs': -9.0, 'peakDb': 0.0};
      calls.clear();
      await service.reanalyzeAll();
      expect(calls, hasLength(3));
      expect(service.knownLufs(queued), -9.0);
    });
  });
}
