import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance Player'**
  String get appTitle;

  /// No description provided for @tabSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get tabSongs;

  /// No description provided for @tabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get tabAlbums;

  /// No description provided for @tabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get tabArtists;

  /// No description provided for @tabFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get tabFolders;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, albums, artists'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get sortAlbum;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortDateAdded;

  /// No description provided for @sortDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sortDuration;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String songCount(int count);

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @willPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Will play next'**
  String get willPlayNext;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get addedToQueue;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get unknownArtist;

  /// No description provided for @unknownAlbum.
  ///
  /// In en, this message translates to:
  /// **'Unknown album'**
  String get unknownAlbum;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @emptyQueue.
  ///
  /// In en, this message translates to:
  /// **'The queue is empty'**
  String get emptyQueue;

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOne;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No music found'**
  String get libraryEmpty;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan library'**
  String get rescan;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(String error);

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get permissionTitle;

  /// No description provided for @permissionBody.
  ///
  /// In en, this message translates to:
  /// **'To find the music on your phone, the app needs permission to read audio files.'**
  String get permissionBody;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get grantPermission;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// No description provided for @minDuration.
  ///
  /// In en, this message translates to:
  /// **'Skip short audio files'**
  String get minDuration;

  /// No description provided for @minDurationOff.
  ///
  /// In en, this message translates to:
  /// **'Don\'t skip'**
  String get minDurationOff;

  /// No description provided for @minDurationValue.
  ///
  /// In en, this message translates to:
  /// **'Shorter than {seconds} s'**
  String minDurationValue(int seconds);

  /// No description provided for @excludedFolders.
  ///
  /// In en, this message translates to:
  /// **'Excluded folders'**
  String get excludedFolders;

  /// No description provided for @excludedFoldersSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 folder excluded} other{{count} folders excluded}}'**
  String excludedFoldersSummary(int count);

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @duckLevel.
  ///
  /// In en, this message translates to:
  /// **'Music volume while navigation speaks'**
  String get duckLevel;

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percent(int value);

  /// No description provided for @pauseOnDuck.
  ///
  /// In en, this message translates to:
  /// **'Pause instead of lowering volume'**
  String get pauseOnDuck;

  /// No description provided for @pauseOnDuckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When navigation or another app speaks'**
  String get pauseOnDuckSubtitle;

  /// No description provided for @tabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get tabPlaylists;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmpty;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @addAllToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add all to playlist'**
  String get addAllToPlaylist;

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedToPlaylist(String name);

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist has no songs yet'**
  String get playlistEmpty;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @saveQueueAsPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Save queue as playlist'**
  String get saveQueueAsPlaylist;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? The music files themselves won\'t be deleted.'**
  String deletePlaylistConfirm(String name);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @shuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get shuffleOn;

  /// No description provided for @shuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle off'**
  String get shuffleOff;

  /// No description provided for @settingsNormalization.
  ///
  /// In en, this message translates to:
  /// **'Volume balance'**
  String get settingsNormalization;

  /// No description provided for @normalize.
  ///
  /// In en, this message translates to:
  /// **'Balance song volume'**
  String get normalize;

  /// No description provided for @normalizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically adjusts each song so they all sound equally loud'**
  String get normalizeSubtitle;

  /// No description provided for @targetLoudness.
  ///
  /// In en, this message translates to:
  /// **'Target loudness'**
  String get targetLoudness;

  /// No description provided for @targetLoudnessHint.
  ///
  /// In en, this message translates to:
  /// **'Higher is louder overall, but more songs need boosting'**
  String get targetLoudnessHint;

  /// No description provided for @lufsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} LUFS'**
  String lufsValue(int value);

  /// No description provided for @lufsRecommended.
  ///
  /// In en, this message translates to:
  /// **'{value} LUFS (recommended)'**
  String lufsRecommended(int value);

  /// No description provided for @analysisProgress.
  ///
  /// In en, this message translates to:
  /// **'Loudness analysis'**
  String get analysisProgress;

  /// No description provided for @analysisProgressValue.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} songs analyzed'**
  String analysisProgressValue(int done, int total);

  /// No description provided for @analysisRunning.
  ///
  /// In en, this message translates to:
  /// **'analyzing…'**
  String get analysisRunning;

  /// No description provided for @reanalyzeAll.
  ///
  /// In en, this message translates to:
  /// **'Re-analyze all songs'**
  String get reanalyzeAll;

  /// No description provided for @normalizationGain.
  ///
  /// In en, this message translates to:
  /// **'Volume balance {gain}'**
  String normalizationGain(String gain);

  /// No description provided for @normalizationAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Volume balance: analyzing…'**
  String get normalizationAnalyzing;

  /// No description provided for @normalizationFailed.
  ///
  /// In en, this message translates to:
  /// **'Volume balance: can\'t analyze this song'**
  String get normalizationFailed;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @eqEnable.
  ///
  /// In en, this message translates to:
  /// **'Use equalizer'**
  String get eqEnable;

  /// No description provided for @eqHint.
  ///
  /// In en, this message translates to:
  /// **'Applied after volume balance. A limiter prevents distortion when bands are boosted.'**
  String get eqHint;

  /// No description provided for @eqFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get eqFlat;

  /// No description provided for @eqBassBoost.
  ///
  /// In en, this message translates to:
  /// **'Bass boost'**
  String get eqBassBoost;

  /// No description provided for @eqTrebleBoost.
  ///
  /// In en, this message translates to:
  /// **'Treble boost'**
  String get eqTrebleBoost;

  /// No description provided for @eqVocal.
  ///
  /// In en, this message translates to:
  /// **'Vocal'**
  String get eqVocal;

  /// No description provided for @eqRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get eqRock;

  /// No description provided for @eqPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get eqPop;

  /// No description provided for @eqClassical.
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get eqClassical;

  /// No description provided for @eqCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get eqCustom;

  /// No description provided for @drivingMode.
  ///
  /// In en, this message translates to:
  /// **'Driving mode'**
  String get drivingMode;

  /// No description provided for @drivingModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Narrows the gap between quiet and loud parts so quiet passages aren\'t drowned out by road noise'**
  String get drivingModeSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
