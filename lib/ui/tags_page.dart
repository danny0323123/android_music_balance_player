import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library.dart';
import '../state/playlists.dart';
import 'common.dart';
import 'playlist_dialogs.dart';

/// 勾選標籤列出歌曲：預設要全部符合，打勾後改成符合任一個。長按標籤可以刪除。
class TagsPage extends ConsumerStatefulWidget {
  const TagsPage({super.key});

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  final _selected = <int>{};
  bool _matchAny = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tags = ref.watch(tagsProvider).value ?? const [];
    _selected.retainAll({for (final t in tags) t.tag.id});
    final songs = filterByTags(
      ref.watch(sortedSongsProvider),
      ref.watch(tagSongsProvider).value ?? const {},
      _selected,
      matchAny: _matchAny,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tags)),
      body: tags.isEmpty
          ? Center(child: Text(l10n.tagsEmpty))
          : SongList(
              songs: songs,
              leading: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tags)
                        GestureDetector(
                          onLongPress: () async {
                            final confirmed = await confirmDelete(
                              context,
                              title: l10n.deleteTag,
                              message: l10n.deleteTagConfirm(t.tag.name),
                            );
                            if (confirmed) {
                              await ref
                                  .read(databaseProvider)
                                  .deleteTag(t.tag.id);
                            }
                          },
                          child: FilterChip(
                            label: Text('${t.tag.name} (${t.songCount})'),
                            selected: _selected.contains(t.tag.id),
                            onSelected: (on) => setState(
                              () => on
                                  ? _selected.add(t.tag.id)
                                  : _selected.remove(t.tag.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  title: Text(l10n.matchAny),
                  value: _matchAny,
                  onChanged: (v) => setState(() => _matchAny = v ?? false),
                ),
                if (_selected.isEmpty) ListTile(title: Text(l10n.pickTagsHint)),
              ],
            ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}
