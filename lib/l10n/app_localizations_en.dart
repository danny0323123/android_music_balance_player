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
}
