// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '均衡播放器';

  @override
  String get tabSongs => '歌曲';

  @override
  String get tabAlbums => '專輯';

  @override
  String get tabArtists => '歌手';

  @override
  String get tabFolders => '資料夾';

  @override
  String get search => '搜尋';

  @override
  String get searchHint => '搜尋歌曲、專輯、歌手';

  @override
  String get noResults => '沒有符合的結果';

  @override
  String get settings => '設定';

  @override
  String get sort => '排序';

  @override
  String get sortTitle => '歌名';

  @override
  String get sortArtist => '歌手';

  @override
  String get sortAlbum => '專輯';

  @override
  String get sortDateAdded => '加入日期';

  @override
  String get sortDuration => '長度';

  @override
  String get sortAscending => '遞增';

  @override
  String get sortDescending => '遞減';

  @override
  String songCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String get playAll => '全部播放';

  @override
  String get playNext => '下一首播放';

  @override
  String get addToQueue => '加入佇列';

  @override
  String get willPlayNext => '將在下一首播放';

  @override
  String get addedToQueue => '已加入佇列';

  @override
  String get unknownArtist => '未知歌手';

  @override
  String get unknownAlbum => '未知專輯';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get queue => '播放佇列';

  @override
  String get emptyQueue => '佇列是空的';

  @override
  String get removeFromQueue => '從佇列移除';

  @override
  String get repeatOff => '不循環';

  @override
  String get repeatAll => '全部循環';

  @override
  String get repeatOne => '單曲循環';

  @override
  String get libraryEmpty => '找不到音樂';

  @override
  String get rescan => '重新掃描音樂庫';

  @override
  String get scanning => '掃描中…';

  @override
  String scanFailed(String error) {
    return '掃描失敗：$error';
  }

  @override
  String get permissionTitle => '需要存取權限';

  @override
  String get permissionBody => '為了找到手機裡的音樂，需要允許讀取音訊檔案。';

  @override
  String get grantPermission => '允許存取';

  @override
  String get openSettings => '開啟設定';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get settingsLibrary => '音樂庫';

  @override
  String get minDuration => '略過較短的音檔';

  @override
  String get minDurationOff => '不略過';

  @override
  String minDurationValue(int seconds) {
    return '短於 $seconds 秒';
  }

  @override
  String get excludedFolders => '排除的資料夾';

  @override
  String excludedFoldersSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已排除 $count 個資料夾',
      zero: '無',
    );
    return '$_temp0';
  }

  @override
  String get settingsPlayback => '播放';

  @override
  String get duckLevel => '導航說話時的音樂音量';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String get pauseOnDuck => '改成暫停播放';

  @override
  String get pauseOnDuckSubtitle => '導航或其他 app 播放語音時';

  @override
  String get tabPlaylists => '播放清單';

  @override
  String get favorites => '我的最愛';

  @override
  String get favoritesEmpty => '還沒有加入任何歌曲';

  @override
  String get addToFavorites => '加入我的最愛';

  @override
  String get removeFromFavorites => '從我的最愛移除';

  @override
  String get addToPlaylist => '加入播放清單';

  @override
  String get addAllToPlaylist => '全部加入播放清單';

  @override
  String addedToPlaylist(String name) {
    return '已加入「$name」';
  }

  @override
  String get newPlaylist => '新增播放清單';

  @override
  String get playlistName => '播放清單名稱';

  @override
  String get playlistEmpty => '這個清單還沒有歌曲';

  @override
  String get removeFromPlaylist => '從清單移除';

  @override
  String get saveQueueAsPlaylist => '將佇列存成播放清單';

  @override
  String get deletePlaylist => '刪除播放清單';

  @override
  String deletePlaylistConfirm(String name) {
    return '要刪除「$name」嗎？清單裡的音樂檔案不會被刪除。';
  }

  @override
  String get create => '建立';

  @override
  String get rename => '重新命名';

  @override
  String get save => '儲存';

  @override
  String get delete => '刪除';

  @override
  String get cancel => '取消';

  @override
  String get shuffle => '隨機播放';

  @override
  String get shuffleOn => '隨機播放：開';

  @override
  String get shuffleOff => '隨機播放：關';

  @override
  String get settingsNormalization => '音量均衡';

  @override
  String get normalize => '平衡每首歌的音量';

  @override
  String get normalizeSubtitle => '自動調整每首歌，讓切歌時聽起來一樣大聲';

  @override
  String get targetLoudness => '目標響度';

  @override
  String get targetLoudnessHint => '數字越大整體越大聲，但需要放大的歌也越多';

  @override
  String lufsValue(int value) {
    return '$value LUFS';
  }

  @override
  String lufsRecommended(int value) {
    return '$value LUFS（建議）';
  }

  @override
  String get analysisProgress => '響度分析';

  @override
  String analysisProgressValue(int done, int total) {
    return '已分析 $done / $total 首';
  }

  @override
  String get analysisRunning => '分析中…';

  @override
  String get reanalyzeAll => '重新分析全部歌曲';

  @override
  String normalizationGain(String gain) {
    return '音量均衡 $gain';
  }

  @override
  String get normalizationAnalyzing => '音量均衡：分析中…';

  @override
  String get normalizationFailed => '音量均衡：這首歌無法分析';

  @override
  String get off => '已關閉';

  @override
  String get equalizer => '等化器';

  @override
  String get eqEnable => '啟用等化器';

  @override
  String get eqHint => '等化器在音量均衡之後套用。調高某些頻段時，限幅器會避免破音。';

  @override
  String get eqFlat => '平坦';

  @override
  String get eqBassBoost => '低音加強';

  @override
  String get eqTrebleBoost => '高音加強';

  @override
  String get eqVocal => '人聲';

  @override
  String get eqRock => '搖滾';

  @override
  String get eqPop => '流行';

  @override
  String get eqClassical => '古典';

  @override
  String get eqCustom => '自訂';

  @override
  String get drivingMode => '開車模式';

  @override
  String get drivingModeSubtitle => '縮小歌曲內的大小聲差距，安靜的段落不會被路噪蓋過';

  @override
  String selectedCount(int count) {
    return '已選 $count 首';
  }

  @override
  String get selectAll => '全選';

  @override
  String get clearSelection => '取消選取';

  @override
  String get selectionHint => '長按另一首可以連續選取';

  @override
  String get editInfo => '編輯資訊';

  @override
  String get editAlbum => '編輯專輯';

  @override
  String get fieldTitle => '歌名';

  @override
  String get fieldArtist => '演出者';

  @override
  String get fieldAlbum => '專輯';

  @override
  String get fieldAlbumArtist => '專輯演出者';

  @override
  String get fieldGenre => '曲風';

  @override
  String get fieldYear => '出版年份';

  @override
  String get changeCover => '更換封面';

  @override
  String get tags => '標籤';

  @override
  String get tagsEmpty => '還沒有任何標籤';

  @override
  String get newTag => '新增標籤';

  @override
  String get tagName => '標籤名稱';

  @override
  String get addTags => '加上標籤';

  @override
  String tagsAdded(String name) {
    return '已加上「$name」';
  }

  @override
  String get matchAny => '符合任一個就顯示';

  @override
  String get pickTagsHint => '選擇標籤來列出歌曲';

  @override
  String get deleteTag => '刪除標籤';

  @override
  String deleteTagConfirm(String name) {
    return '要刪除標籤「$name」嗎？歌曲本身不會被刪除。';
  }

  @override
  String get deleteSongs => '刪除歌曲';

  @override
  String deleteSongsConfirm(int count) {
    return '要從手機刪除這 $count 首歌的檔案嗎？刪除後無法復原。';
  }

  @override
  String deleteFailed(int count) {
    return '有 $count 首刪除失敗';
  }

  @override
  String get saved => '已儲存';

  @override
  String get saving => '儲存中…';

  @override
  String writeFailed(int count) {
    return '有 $count 個檔案寫入失敗（可能是不支援的格式）';
  }

  @override
  String get fileAccessTitle => '需要檔案存取權';

  @override
  String get fileAccessBody =>
      '編輯歌曲資訊、刪除歌曲、備份需要直接修改手機上的檔案。請在接下來的設定頁打開「允許存取所有檔案」。';

  @override
  String get goToSettings => '前往設定';

  @override
  String get backup => '備份';

  @override
  String get exportBackup => '匯出備份';

  @override
  String get exportBackupSubtitle => '播放清單、我的最愛、標籤';

  @override
  String get importBackup => '匯入備份';

  @override
  String exportedTo(String path) {
    return '已存到 $path';
  }

  @override
  String get noBackupFound => '下載資料夾裡沒有備份檔';

  @override
  String importFailed(String error) {
    return '匯入失敗：$error';
  }

  @override
  String importDone(int found, int missing) {
    return '已匯入 $found 首，$missing 首在這支手機上找不到';
  }
}
