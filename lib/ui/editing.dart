import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/database.dart';
import '../platform/media_store.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../state/playlists.dart';
import 'common.dart';
import 'playlist_dialogs.dart';

/// 改檔案（編輯、刪除、備份）前確認有「所有檔案存取權」，沒有的話說明後帶去設定頁。
Future<bool> ensureFileAccess(BuildContext context) async {
  final sdk = await MediaStoreChannel.sdkInt();
  // Android 10 以下沒有這個權限，用一般的儲存空間權限
  final permission = sdk >= 30
      ? Permission.manageExternalStorage
      : Permission.storage;
  if (await permission.isGranted) return true;
  if (!context.mounted) return false;
  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.fileAccessTitle),
      content: Text(l10n.fileAccessBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.goToSettings),
        ),
      ],
    ),
  );
  if (go != true) return false;
  return (await permission.request()).isGranted;
}

/// 確認後把檔案從手機刪除，並從播放佇列拿掉。
Future<void> deleteSongs(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await confirmDelete(
    context,
    title: l10n.deleteSongs,
    message: l10n.deleteSongsConfirm(songs.length),
  );
  if (!confirmed || !context.mounted) return;
  if (!await ensureFileAccess(context)) return;

  final failed = (await MediaStoreChannel.deleteFiles([
    for (final s in songs) s.path,
  ])).toSet();
  await ref.read(playerProvider).removeSongs({
    for (final s in songs)
      if (!failed.contains(s.path)) s.id,
  });
  await ref.read(scanProvider.notifier).scan();
  if (failed.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.deleteFailed(failed.length))),
    );
  }
}

Future<(int, String)?> _createTag(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final name = await askPlaylistName(
    context,
    title: l10n.newTag,
    confirmLabel: l10n.create,
    label: l10n.tagName,
  );
  if (name == null) return null;
  return (await ref.read(databaseProvider).createTag(name), name);
}

/// 「加上標籤」：選一個標籤（或新增一個）加到 [songs]。
Future<void> addTagSheet(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showModalBottomSheet<(int, String)>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final tags = ref.watch(tagsProvider).value ?? const [];
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l10n.addTags,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.newTag),
              onTap: () async {
                final navigator = Navigator.of(context);
                final tag = await _createTag(context, ref);
                if (tag != null) navigator.pop(tag);
              },
            ),
            for (final t in tags)
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(t.tag.name),
                subtitle: Text(l10n.songCount(t.songCount)),
                onTap: () => Navigator.of(context).pop((t.tag.id, t.tag.name)),
              ),
          ],
        );
      },
    ),
  );
  if (picked == null) return;
  final (id, name) = picked;
  await ref.read(databaseProvider).addTagToSongs(id, songs.map((s) => s.id));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.tagsAdded(name))));
}

/// 從相簿挑一張圖當封面，縮到 1000px 以內。
Future<String?> _pickCover() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1000,
    maxHeight: 1000,
    imageQuality: 90,
  );
  return image?.path;
}

/// 編輯頁上方的封面，點一下換圖。
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.song,
    required this.picked,
    required this.onPicked,
  });

  final Song song;
  final String? picked;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    return Column(
      children: [
        SizedBox.square(
          dimension: 160,
          child: picked == null
              ? Artwork(song: song, radius: 12)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(picked), fit: BoxFit.cover),
                ),
        ),
        TextButton.icon(
          onPressed: () async {
            final path = await _pickCover();
            if (path != null) onPicked(path);
          },
          icon: const Icon(Icons.image_outlined),
          label: Text(context.l10n.changeCover),
        ),
      ],
    );
  }
}

/// 可以打字、也可以從清單挑的輸入框（專輯、曲風）。
Widget _pickOrType(
  TextEditingController controller,
  String label,
  Iterable<String> options,
) => DropdownMenu<String>(
  controller: controller,
  label: Text(label),
  enableFilter: true,
  requestFocusOnTap: true,
  expandedInsets: EdgeInsets.zero,
  menuHeight: 300,
  dropdownMenuEntries: [
    for (final o in options) DropdownMenuEntry(value: o, label: o),
  ],
);

/// 存檔的共同流程：寫進檔案（需要權限）、重新掃描、失敗時提示。回傳是否成功。
Future<bool> _writeFiles(
  BuildContext context,
  WidgetRef ref,
  List<String> paths,
  Map<String, String> fields,
  String? artPath,
) async {
  if (fields.isEmpty && artPath == null) return true;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ensureFileAccess(context)) return false;
  final failed = await MediaStoreChannel.writeTags(
    paths,
    fields,
    artPath: artPath,
  );
  await ref.read(scanProvider.notifier).scan();
  if (failed.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.writeFailed(failed.length))),
    );
  }
  return failed.length < paths.length;
}

/// 編輯一首歌：歌名、演出者、專輯、曲風、年份、封面寫進檔案；標籤存在 app 裡。
class EditSongPage extends ConsumerStatefulWidget {
  const EditSongPage({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<EditSongPage> createState() => _EditSongPageState();
}

class _EditSongPageState extends ConsumerState<EditSongPage> {
  late final _title = TextEditingController(text: widget.song.title);
  late final _artist = TextEditingController(text: widget.song.artist ?? '');
  late final _album = TextEditingController(text: widget.song.album ?? '');
  late final _genre = TextEditingController(text: widget.song.genre ?? '');
  late final _year = TextEditingController(
    text: widget.song.year?.toString() ?? '',
  );
  String? _art;
  Set<int>? _tags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(databaseProvider)
        .tagIdsOf(widget.song.id)
        .then((ids) => mounted ? setState(() => _tags = ids) : null);
  }

  @override
  void dispose() {
    for (final c in [_title, _artist, _album, _genre, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final song = widget.song;
    final fields = <String, String>{};
    void put(String key, TextEditingController c, String? old) {
      final value = c.text.trim();
      if (value != (old ?? '')) fields[key] = value;
    }

    put('title', _title, song.title);
    put('artist', _artist, song.artist);
    put('album', _album, song.album);
    put('genre', _genre, song.genre);
    put('year', _year, song.year?.toString());
    final album = fields['album'];
    if (album != null) {
      // 移到既有的專輯時，專輯演出者也跟那張專輯一樣，才會分在同一組
      final target = ref
          .read(albumsProvider)
          .where((a) => a.name == album)
          .firstOrNull;
      if (target != null && target.albumArtist != song.albumArtist) {
        fields['albumArtist'] = target.albumArtist ?? '';
      }
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final tags = _tags;
    if (tags != null) {
      await ref.read(databaseProvider).setSongTags(song.id, tags);
    }
    if (!mounted) return;
    final ok = await _writeFiles(context, ref, [song.path], fields, _art);
    if (!mounted) return;
    ok ? navigator.pop() : setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(allSongsProvider).value ?? const <Song>[];
    final albums = {for (final s in all) ?s.album}.toList()..sort(compareText);
    final genres = {for (final s in all) ?s.genre}.toList()..sort(compareText);
    final tags = ref.watch(tagsProvider).value ?? const [];
    final selected = _tags;
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editInfo),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CoverPicker(
              song: widget.song,
              picked: _art,
              onPicked: (p) => setState(() => _art = p),
            ),
            gap,
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
            ),
            gap,
            TextField(
              controller: _artist,
              decoration: InputDecoration(labelText: l10n.fieldArtist),
            ),
            gap,
            _pickOrType(_album, l10n.fieldAlbum, albums),
            gap,
            _pickOrType(_genre, l10n.fieldGenre, genres),
            gap,
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.fieldYear),
            ),
            gap,
            Text(l10n.tags, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (selected != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags)
                    FilterChip(
                      label: Text(t.tag.name),
                      selected: selected.contains(t.tag.id),
                      onSelected: (on) => setState(
                        () => on
                            ? selected.add(t.tag.id)
                            : selected.remove(t.tag.id),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add),
                    label: Text(l10n.newTag),
                    onPressed: () async {
                      final tag = await _createTag(context, ref);
                      if (tag != null) setState(() => selected.add(tag.$1));
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 編輯專輯：名稱、專輯演出者、年份、封面寫進專輯裡的每一首歌。
/// 存檔後回傳新的專輯 key（名稱或演出者改了，key 會跟著變）。
class EditAlbumPage extends ConsumerStatefulWidget {
  const EditAlbumPage({super.key, required this.album});

  final Album album;

  @override
  ConsumerState<EditAlbumPage> createState() => _EditAlbumPageState();
}

class _EditAlbumPageState extends ConsumerState<EditAlbumPage> {
  late final _name = TextEditingController(text: widget.album.name ?? '');
  late final _artist = TextEditingController(text: widget.album.artist ?? '');
  late final _year = TextEditingController(
    text: widget.album.year?.toString() ?? '',
  );
  String? _art;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _artist, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final album = widget.album;
    final fields = <String, String>{
      if (_name.text.trim() != (album.name ?? '')) 'album': _name.text.trim(),
      if (_artist.text.trim() != (album.artist ?? ''))
        'albumArtist': _artist.text.trim(),
      if (_year.text.trim() != (album.year?.toString() ?? ''))
        'year': _year.text.trim(),
    };
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await _writeFiles(
      context,
      ref,
      [for (final s in album.songs) s.path],
      fields,
      _art,
    );
    if (!mounted) return;
    if (!ok) return setState(() => _saving = false);
    final name = fields['album'] ?? album.name ?? '';
    final artist = fields['albumArtist'] ?? album.albumArtist ?? '';
    navigator.pop('$name\u0000$artist');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editAlbum),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CoverPicker(
              song: widget.album.songs.first,
              picked: _art,
              onPicked: (p) => setState(() => _art = p),
            ),
            gap,
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.fieldAlbum),
            ),
            gap,
            TextField(
              controller: _artist,
              decoration: InputDecoration(labelText: l10n.fieldAlbumArtist),
            ),
            gap,
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.fieldYear),
            ),
          ],
        ),
      ),
    );
  }
}

// shortcut: 固定用主要儲存空間的 Download 資料夾，有記憶卡或多使用者時才需要改成查系統路徑
const _backupDir = '/storage/emulated/0/Download';
const _backupPrefix = 'MusicBalance-backup-';

Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ensureFileAccess(context)) return;
  final data = await ref.read(databaseProvider).exportBackup();
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  final file = File('$_backupDir/$_backupPrefix$stamp.json');
  await file.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
  messenger.showSnackBar(SnackBar(content: Text(l10n.exportedTo(file.path))));
}

Future<void> importBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ensureFileAccess(context) || !context.mounted) return;
  final files = Directory(_backupDir).listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith(_backupPrefix) && name.endsWith('.json');
  }).toList()..sort((a, b) => b.path.compareTo(a.path));
  if (files.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.noBackupFound)));
    return;
  }
  final file = await showDialog<File>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.importBackup),
      children: [
        for (final f in files)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(f),
            child: Text(f.uri.pathSegments.last),
          ),
      ],
    ),
  );
  if (file == null) return;
  try {
    final data = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final result = await ref.read(databaseProvider).importBackup(data);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.importDone(result.found, result.missing))),
    );
  } catch (e) {
    // 檔案被改壞或不是這個 app 的備份
    messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
  }
}
