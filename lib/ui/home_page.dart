import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library.dart';
import '../state/settings.dart';
import 'common.dart';
import 'editing.dart';
import 'playlists_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scanning = ref.watch(scanProvider);
    final titles = [
      l10n.tabSongs,
      l10n.tabPlaylists,
      l10n.tabAlbums,
      l10n.tabArtists,
      l10n.tabFolders,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).pushNamed('/search'),
          ),
          if (_tab == 0) const _SortButton(),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
        bottom: scanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _SongsTab(),
          PlaylistsTab(),
          _AlbumsTab(),
          _ArtistsTab(),
          _FoldersTab(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.music_note_outlined),
                selectedIcon: const Icon(Icons.music_note),
                label: l10n.tabSongs,
              ),
              NavigationDestination(
                icon: const Icon(Icons.queue_music_outlined),
                selectedIcon: const Icon(Icons.queue_music),
                label: l10n.tabPlaylists,
              ),
              NavigationDestination(
                icon: const Icon(Icons.album_outlined),
                selectedIcon: const Icon(Icons.album),
                label: l10n.tabAlbums,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l10n.tabArtists,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder),
                label: l10n.tabFolders,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortButton extends ConsumerWidget {
  const _SortButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final labels = {
      SongSort.title: l10n.sortTitle,
      SongSort.artist: l10n.sortArtist,
      SongSort.album: l10n.sortAlbum,
      SongSort.dateAdded: l10n.sortDateAdded,
      SongSort.duration: l10n.sortDuration,
    };
    return PopupMenuButton<void Function()>(
      tooltip: l10n.sort,
      icon: const Icon(Icons.sort),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        for (final e in labels.entries)
          CheckedPopupMenuItem(
            value: () => notifier.setSongSort(e.key),
            checked: settings.songSort == e.key,
            child: Text(e.value),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: () => notifier.setSortAscending(true),
          checked: settings.sortAscending,
          child: Text(l10n.sortAscending),
        ),
        CheckedPopupMenuItem(
          value: () => notifier.setSortAscending(false),
          checked: !settings.sortAscending,
          child: Text(l10n.sortDescending),
        ),
      ],
    );
  }
}

/// 音樂庫是空的時候顯示，提供重新掃描。
class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanning = ref.watch(scanProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(scanning ? context.l10n.scanning : context.l10n.libraryEmpty),
          const SizedBox(height: 16),
          if (!scanning)
            FilledButton.tonal(
              onPressed: () => scanLibrary(context, ref),
              child: Text(context.l10n.rescan),
            ),
        ],
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(sortedSongsProvider);
    if (songs.isEmpty) return const _EmptyLibrary();
    return SongList(songs: songs, onRefresh: () => scanLibrary(context, ref));
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    if (albums.isEmpty) return const _EmptyLibrary();

    // 格子高度 = 正方形封面 + 間距 + 兩行文字，依照實際寬度和字體大小計算，
    // 用固定長寬比的話，字體放大或螢幕較窄時文字會超出格子
    const padding = 12.0, spacing = 12.0, gap = 6.0;
    final textTheme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double lineHeight(TextStyle? s) =>
        scaler.scale(s?.fontSize ?? 14) * (s?.height ?? 1.2);
    final textHeight =
        lineHeight(textTheme.bodyLarge) + lineHeight(textTheme.bodySmall) + 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding * 2;
        final columns = ((width + spacing) / (180 + spacing)).ceil();
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return GridView.builder(
          padding: const EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: tileWidth + gap + textHeight,
          ),
          itemCount: albums.length,
          itemBuilder: (context, i) {
            final album = albums[i];
            final first = album.songs.first;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlbumPage(albumKey: album.key),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Artwork(song: first, radius: 8),
                  ),
                  const SizedBox(height: gap),
                  Text(
                    albumName(context, album.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge,
                  ),
                  Text(
                    artistName(context, album.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    if (artists.isEmpty) return const _EmptyLibrary();
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final artist = artists[i];
        final name = artistName(context, artist.name);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(context.l10n.songCount(artist.songs.length)),
          onTap: () => openArtist(context, artist),
        );
      },
    );
  }
}

class _FoldersTab extends ConsumerWidget {
  const _FoldersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    if (folders.isEmpty) return const _EmptyLibrary();
    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final folder = folders[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${context.l10n.songCount(folder.songs.length)} · ${folder.path}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SongListPage(
                title: folder.name,
                songs: (ref) =>
                    ref
                        .watch(foldersProvider)
                        .where((f) => f.path == folder.path)
                        .firstOrNull
                        ?.songs ??
                    const [],
              ),
            ),
          ),
        );
      },
    );
  }
}

void openArtist(BuildContext context, Artist artist) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SongListPage(
        title: artistName(context, artist.name),
        songs: (ref) =>
            ref
                .watch(artistsProvider)
                .where((a) => a.name == artist.name)
                .firstOrNull
                ?.songs ??
            const [],
      ),
    ),
  );
}

/// 專輯頁。編輯專輯名稱或演出者後 key 會變，跟著換成新的 key。
class AlbumPage extends ConsumerStatefulWidget {
  const AlbumPage({super.key, required this.albumKey});

  final String albumKey;

  @override
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
  late String _key = widget.albumKey;

  @override
  Widget build(BuildContext context) {
    final album = ref
        .watch(albumsProvider)
        .where((a) => a.key == _key)
        .firstOrNull;
    return SongListPage(
      title: albumName(context, album?.name),
      songs: (_) => album?.songs ?? const [],
      actions: [
        if (album != null)
          IconButton(
            tooltip: context.l10n.editAlbum,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final key = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => EditAlbumPage(album: album)),
              );
              if (key != null) setState(() => _key = key);
            },
          ),
      ],
    );
  }
}
