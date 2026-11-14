import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/audio/play_queue.dart';
import 'package:music_balance/data/database.dart';

Song _song(int id) => Song(
  id: id,
  uri: 'content://media/external/audio/media/$id',
  path: '/Music/$id.mp3',
  folder: '/Music',
  title: 'Song $id',
  albumId: 1,
  durationMs: 180000,
  trackNumber: 0,
  dateAdded: 0,
  dateModified: 0,
);

List<int> _ids(PlayQueue q) => [for (final s in q.songs) s.id];

void main() {
  final songs = [for (var i = 1; i <= 8; i++) _song(i)];

  test('setSongs without shuffle keeps order and start index', () {
    final q = PlayQueue()..setSongs(songs, 3, shuffle: false);
    expect(_ids(q), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(q.current!.id, 4);
    expect(q.shuffled, isFalse);
  });

  test('shuffle puts the current song first and keeps every song', () {
    final q = PlayQueue(random: Random(1))..setSongs(songs, 3, shuffle: true);
    expect(q.index, 0);
    expect(q.current!.id, 4);
    expect(_ids(q).toSet(), {1, 2, 3, 4, 5, 6, 7, 8});
    expect(q.shuffled, isTrue);
  });

  test('turning shuffle off restores order and stays on the same song', () {
    final q = PlayQueue(random: Random(2))..setSongs(songs, 0, shuffle: true);
    q.index = 5;
    final playing = q.current!.id;
    q.setShuffle(false);
    expect(_ids(q), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(q.current!.id, playing);
  });

  test('songs added while shuffled also go into the original order', () {
    final q = PlayQueue(random: Random(3))..setSongs(songs, 2, shuffle: true);
    q.insertNext(_song(100));
    q.add(_song(200));
    expect(_ids(q)[1], 100);
    expect(_ids(q).last, 200);
    q.setShuffle(false);
    // 「下一首播放」插在原本順序中目前那首（3）的後面
    expect(_ids(q), [1, 2, 3, 100, 4, 5, 6, 7, 8, 200]);
    expect(q.current!.id, 3);
  });

  test('duplicates are tracked separately when unshuffling', () {
    final q = PlayQueue(random: Random(4))
      ..setSongs([_song(1), _song(2), _song(1)], 2, shuffle: true);
    q.setShuffle(false);
    expect(_ids(q), [1, 2, 1]);
    expect(q.index, 2); // 是第二個「1」，不是第一個
  });

  test('removing the current song moves to the next one', () {
    final q = PlayQueue()..setSongs(songs, 7, shuffle: false);
    expect(q.removeAt(7), isTrue);
    expect(q.current!.id, 7); // 原本是最後一首，退回前一首
    q.index = 2;
    expect(q.removeAt(0), isFalse);
    expect(q.current!.id, 3);
  });

  test('move keeps the index on the same song', () {
    final q = PlayQueue()..setSongs(songs, 2, shuffle: false);
    q.move(0, 5);
    expect(q.current!.id, 3);
    q.move(q.index, 0);
    expect(q.index, 0);
    expect(q.current!.id, 3);
  });

  test('restore rebuilds shuffle state from saved ids', () {
    final q = PlayQueue()
      ..restore(
        [_song(3), _song(1), _song(2)],
        1,
        [_song(1), _song(2), _song(3)],
      );
    expect(q.shuffled, isTrue);
    expect(q.current!.id, 1);
    q.setShuffle(false);
    expect(_ids(q), [1, 2, 3]);
    expect(q.current!.id, 1);
  });
}
