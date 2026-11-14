import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/l10n/app_localizations.dart';
import 'package:music_balance/ui/playlist_dialogs.dart';

void main() {
  testWidgets('playlist name dialog returns the name and closes cleanly', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await askPlaylistName(
              context,
              title: 'New playlist',
              confirmLabel: 'Create',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Drive  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, 'Drive');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
