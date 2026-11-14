import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'state/settings.dart';
import 'ui/home_page.dart';
import 'ui/now_playing_page.dart';
import 'ui/permission_gate.dart';
import 'ui/queue_page.dart';
import 'ui/search_page.dart';
import 'ui/settings_page.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  static const _seed = Colors.teal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 繁體中文排第一：系統語言不支援時預設用中文；zh_TW 讓內建元件也顯示繁體
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      routes: {
        '/': (_) => const PermissionGate(child: HomePage()),
        '/now-playing': (_) => const NowPlayingPage(),
        '/queue': (_) => const QueuePage(),
        '/search': (_) => const SearchPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}
