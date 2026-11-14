import 'dart:ui';

import 'app_localizations.dart';

/// 依照手機語言取得在地化文字。播放服務（Android Auto、桌面小工具）沒有 BuildContext，
/// 而且可能在畫面沒開的時候執行。
AppLocalizations systemLocalizations() {
  final locale = PlatformDispatcher.instance.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(supported ? locale : const Locale('en'));
}
