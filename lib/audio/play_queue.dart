import 'dart:math';

import '../data/database.dart';

/// 佇列裡的一個位置。用物件身分區分同一首歌的多個副本。
class _Item {
  _Item(this.song);
  Song song;
}

/// 播放佇列的純邏輯（不碰播放器，方便測試）。
///
/// 隨機播放：把佇列打亂成一份暫時的順序（目前這首排第一），照這個順序播；
/// 關掉時恢復原本的順序，並停在同一首歌上。
class PlayQueue {
  PlayQueue({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<_Item> _items = [];
  List<_Item>? _original;
  int _index = -1;

  List<Song> get songs => [for (final i in _items) i.song];
  int get index => _index;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
  bool get shuffled => _original != null;
  Song? get current => _index >= 0 ? _items[_index].song : null;

  /// 隨機播放時的原始順序（存檔用），沒有隨機播放時為 null。
  List<Song>? get originalSongs =>
      _original == null ? null : [for (final i in _original!) i.song];

  set index(int value) {
    assert(value >= 0 && value < _items.length);
    _index = value;
  }

  void setSongs(List<Song> songs, int start, {required bool shuffle}) {
    _items = [for (final s in songs) _Item(s)];
    _original = null;
    _index = start;
    if (shuffle) _shuffleKeepingCurrent();
  }

  /// 隨機播放整份清單，從隨機的一首開始。
  void setSongsShuffled(List<Song> songs) =>
      setSongs(songs, _random.nextInt(songs.length), shuffle: true);

  void setShuffle(bool on) {
    if (on == shuffled || _items.isEmpty) return;
    if (on) {
      _shuffleKeepingCurrent();
    } else {
      final current = _items[_index];
      _items = _original!;
      _original = null;
      _index = _items.indexOf(current);
    }
  }

  void _shuffleKeepingCurrent() {
    _original = List.of(_items);
    final current = _items[_index];
    final rest = List.of(_items)
      ..removeAt(_index)
      ..shuffle(_random);
    _items = [current, ...rest];
    _index = 0;
  }

  void insertNext(Song song) {
    final item = _Item(song);
    final current = _index >= 0 ? _items[_index] : null;
    _items.insert(_index + 1, item);
    final original = _original;
    if (original != null) {
      original.insert(original.indexOf(current!) + 1, item);
    }
  }

  void add(Song song) {
    final item = _Item(song);
    _items.add(item);
    _original?.add(item);
  }

  /// 歌曲資訊被編輯後，換成資料庫裡的新版本（順序不變）。
  void updateSongs(Map<int, Song> byId) {
    for (final item in _items) {
      item.song = byId[item.song.id] ?? item.song;
    }
  }

  /// 回傳被移除的是不是目前這首。移除目前這首後，[index] 會指向接下來那首。
  bool removeAt(int i) {
    final item = _items.removeAt(i);
    _original?.remove(item);
    if (_items.isEmpty) {
      _index = -1;
      _original = null;
      return true;
    }
    if (i < _index) _index--;
    if (i == _index) {
      _index = min(_index, _items.length - 1);
      return true;
    }
    return false;
  }

  /// [to] 是移除 [from] 之後要插入的位置。只影響目前的（可能是隨機的）順序。
  void move(int from, int to) {
    if (from == to) return;
    _items.insert(to, _items.removeAt(from));
    if (from == _index) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index--;
    } else if (from > _index && to <= _index) {
      _index++;
    }
  }

  /// 從存檔恢復。[original] 不為 null 表示當時是隨機播放。
  void restore(List<Song> songs, int index, List<Song>? original) {
    _original = null;
    if (original == null) {
      _items = [for (final s in songs) _Item(s)];
    } else {
      // 把隨機順序的每一首對應回原始順序裡的同一個項目
      final orig = [for (final s in original) _Item(s)];
      final pool = <int, List<_Item>>{};
      for (final item in orig) {
        pool.putIfAbsent(item.song.id, () => []).add(item);
      }
      _items = [
        for (final s in songs)
          if (pool[s.id]?.isNotEmpty ?? false)
            pool[s.id]!.removeAt(0)
          else
            _Item(s),
      ];
      for (final item in _items) {
        if (!orig.contains(item)) orig.add(item);
      }
      orig.removeWhere((item) => !_items.contains(item));
      _original = orig;
    }
    _index = _items.isEmpty ? -1 : index.clamp(0, _items.length - 1);
  }
}
