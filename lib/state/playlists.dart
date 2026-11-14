import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'library.dart';

final playlistsProvider = StreamProvider<List<PlaylistSummary>>(
  (ref) => ref.watch(databaseProvider).watchPlaylists(),
);

final playlistEntriesProvider = StreamProvider.autoDispose
    .family<List<PlaylistEntry>, int>(
      (ref, id) => ref.watch(databaseProvider).watchPlaylistEntries(id),
    );

final favoriteIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(databaseProvider).watchFavoriteIds(),
);

final favoriteSongsProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(databaseProvider).watchFavoriteSongs(),
);

final isFavoriteProvider = Provider.family<bool, int>(
  (ref, songId) =>
      ref.watch(favoriteIdsProvider).value?.contains(songId) ?? false,
);
