import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/library.dart';
import '../state/player.dart';
import 'common.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    bool match(String? s) => s != null && s.toLowerCase().contains(q);

    final songs = q.isEmpty
        ? const <Song>[]
        : ref
              .watch(sortedSongsProvider)
              .where((s) => match(s.title) || match(s.artist) || match(s.album))
              .toList();
    final albums = q.isEmpty
        ? const <Album>[]
        : ref.watch(albumsProvider).where((a) => match(a.name)).toList();
    final artists = q.isEmpty
        ? const <Artist>[]
        : ref.watch(artistsProvider).where((a) => match(a.name)).toList();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: q.isNotEmpty && songs.isEmpty && albums.isEmpty && artists.isEmpty
          ? Center(child: Text(l10n.noResults))
          : ListView(
              children: [
                if (artists.isNotEmpty) header(l10n.tabArtists),
                for (final a in artists)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(artistName(context, a.name)),
                    subtitle: Text(l10n.songCount(a.songs.length)),
                    onTap: () => _open(artistName(context, a.name), a.songs),
                  ),
                if (albums.isNotEmpty) header(l10n.tabAlbums),
                for (final a in albums)
                  ListTile(
                    leading: Artwork(
                      albumId: a.id,
                      songId: a.songs.first.id,
                      size: 48,
                    ),
                    title: Text(albumName(context, a.name)),
                    subtitle: Text(artistName(context, a.artist)),
                    onTap: () => _open(albumName(context, a.name), a.songs),
                  ),
                if (songs.isNotEmpty) header(l10n.tabSongs),
                for (final (i, song) in songs.indexed)
                  SongTile(
                    song: song,
                    onTap: () => ref.read(playerProvider).playSongs(songs, i),
                  ),
              ],
            ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }

  void _open(String title, List<Song> songs) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongListPage(title: title, songs: songs),
      ),
    );
  }
}
