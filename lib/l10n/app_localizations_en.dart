// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Balance Player';

  @override
  String get tabSongs => 'Songs';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabArtists => 'Artists';

  @override
  String get tabFolders => 'Folders';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search songs, albums, artists';

  @override
  String get noResults => 'No results';

  @override
  String get settings => 'Settings';

  @override
  String get sort => 'Sort';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Date added';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get willPlayNext => 'Will play next';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get unknownAlbum => 'Unknown album';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get queue => 'Queue';

  @override
  String get emptyQueue => 'The queue is empty';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAll => 'Repeat all';

  @override
  String get repeatOne => 'Repeat one';

  @override
  String get libraryEmpty => 'No music found';

  @override
  String get rescan => 'Rescan library';

  @override
  String get scanning => 'Scanning…';

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get permissionTitle => 'Permission needed';

  @override
  String get permissionBody =>
      'To find the music on your phone, the app needs permission to read audio files.';

  @override
  String get grantPermission => 'Allow access';

  @override
  String get openSettings => 'Open settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get minDuration => 'Skip short audio files';

  @override
  String get minDurationOff => 'Don\'t skip';

  @override
  String minDurationValue(int seconds) {
    return 'Shorter than $seconds s';
  }

  @override
  String get excludedFolders => 'Excluded folders';

  @override
  String excludedFoldersSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders excluded',
      one: '1 folder excluded',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get duckLevel => 'Music volume while navigation speaks';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String get pauseOnDuck => 'Pause instead of lowering volume';

  @override
  String get pauseOnDuckSubtitle => 'When navigation or another app speaks';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get addAllToPlaylist => 'Add all to playlist';

  @override
  String addedToPlaylist(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistEmpty => 'This playlist has no songs yet';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get saveQueueAsPlaylist => 'Save queue as playlist';

  @override
  String get deletePlaylist => 'Delete playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Delete \"$name\"? The music files themselves won\'t be deleted.';
  }

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get shuffleOn => 'Shuffle on';

  @override
  String get shuffleOff => 'Shuffle off';

  @override
  String get settingsNormalization => 'Volume balance';

  @override
  String get normalize => 'Balance song volume';

  @override
  String get normalizeSubtitle =>
      'Automatically adjusts each song so they all sound equally loud';

  @override
  String get targetLoudness => 'Target loudness';

  @override
  String get targetLoudnessHint =>
      'Higher is louder overall, but more songs need boosting';

  @override
  String lufsValue(int value) {
    return '$value LUFS';
  }

  @override
  String lufsRecommended(int value) {
    return '$value LUFS (recommended)';
  }

  @override
  String get analysisProgress => 'Loudness analysis';

  @override
  String analysisProgressValue(int done, int total) {
    return '$done / $total songs analyzed';
  }

  @override
  String get analysisRunning => 'analyzing…';

  @override
  String get reanalyzeAll => 'Re-analyze all songs';

  @override
  String normalizationGain(String gain) {
    return 'Volume balance $gain';
  }

  @override
  String get normalizationAnalyzing => 'Volume balance: analyzing…';

  @override
  String get normalizationFailed => 'Volume balance: can\'t analyze this song';

  @override
  String get off => 'Off';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get eqEnable => 'Use equalizer';

  @override
  String get eqHint =>
      'Applied after volume balance. A limiter prevents distortion when bands are boosted.';

  @override
  String get eqFlat => 'Flat';

  @override
  String get eqBassBoost => 'Bass boost';

  @override
  String get eqTrebleBoost => 'Treble boost';

  @override
  String get eqVocal => 'Vocal';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqPop => 'Pop';

  @override
  String get eqClassical => 'Classical';

  @override
  String get eqCustom => 'Custom';

  @override
  String get drivingMode => 'Driving mode';

  @override
  String get drivingModeSubtitle =>
      'Narrows the gap between quiet and loud parts so quiet passages aren\'t drowned out by road noise';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get selectionHint => 'Long-press another song to select a range';

  @override
  String get editInfo => 'Edit info';

  @override
  String get editAlbum => 'Edit album';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldArtist => 'Artist';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Album artist';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get fieldYear => 'Year';

  @override
  String get changeCover => 'Change cover';

  @override
  String get tags => 'Tags';

  @override
  String get tagsEmpty => 'No tags yet';

  @override
  String get newTag => 'New tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get addTags => 'Add tag';

  @override
  String tagsAdded(String name) {
    return 'Tagged \"$name\"';
  }

  @override
  String get matchAny => 'Show songs matching any tag';

  @override
  String get pickTagsHint => 'Pick tags to list songs';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String deleteTagConfirm(String name) {
    return 'Delete the tag \"$name\"? The songs themselves won\'t be deleted.';
  }

  @override
  String get deleteSongs => 'Delete songs';

  @override
  String deleteSongsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'the files of these $count songs',
      one: 'this song\'s file',
    );
    return 'Delete $_temp0 from your phone? This can\'t be undone.';
  }

  @override
  String deleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0 couldn\'t be deleted';
  }

  @override
  String get saved => 'Saved';

  @override
  String get saving => 'Saving…';

  @override
  String writeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 couldn\'t be written (the format may not be supported)';
  }

  @override
  String get fileAccessTitle => 'File access needed';

  @override
  String get fileAccessBody =>
      'Editing song info, deleting songs and backups change files on your phone directly. On the next screen, turn on \"Allow access to manage all files\".';

  @override
  String get goToSettings => 'Go to settings';

  @override
  String get backup => 'Backup';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get exportBackupSubtitle => 'Playlists, favorites and tags';

  @override
  String get importBackup => 'Import backup';

  @override
  String exportedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get noBackupFound => 'No backup file in the Download folder';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String importDone(int found, int missing) {
    return 'Imported $found songs; $missing aren\'t on this phone';
  }
}
