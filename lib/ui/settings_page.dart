import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/effects.dart';
import '../audio/loudness.dart';
import '../state/library.dart';
import '../state/loudness.dart';
import '../state/settings.dart';
import 'common.dart';
import 'equalizer_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _minDurationChoices = [0, 10, 30, 60];
  static const _targetChoices = [-18.0, -16.0, -14.0, -12.0, -10.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scanning = ref.watch(scanProvider);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          section(l10n.settingsNormalization),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq),
            title: Text(l10n.normalize),
            subtitle: Text(l10n.normalizeSubtitle),
            value: settings.normalizeEnabled,
            onChanged: notifier.setNormalizeEnabled,
          ),
          ListTile(
            enabled: settings.normalizeEnabled,
            leading: const Icon(Icons.tune),
            title: Text(l10n.targetLoudness),
            subtitle: Text(
              '${l10n.lufsValue(settings.normalizeTarget.round())}\n'
              '${l10n.targetLoudnessHint}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<double>(
              enabled: settings.normalizeEnabled,
              initialValue: settings.normalizeTarget,
              onSelected: notifier.setNormalizeTarget,
              itemBuilder: (context) => [
                for (final t in _targetChoices)
                  PopupMenuItem(
                    value: t,
                    child: Text(
                      t == defaultTargetLufs
                          ? l10n.lufsRecommended(t.round())
                          : l10n.lufsValue(t.round()),
                    ),
                  ),
              ],
            ),
          ),
          const _AnalysisProgressTile(),
          section(l10n.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          section(l10n.settingsLibrary),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(scanning ? l10n.scanning : l10n.rescan),
            enabled: !scanning,
            onTap: () => scanLibrary(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.minDuration),
            subtitle: Text(
              settings.minDurationSec == 0
                  ? l10n.minDurationOff
                  : l10n.minDurationValue(settings.minDurationSec),
            ),
            trailing: PopupMenuButton<int>(
              initialValue: settings.minDurationSec,
              onSelected: notifier.setMinDuration,
              itemBuilder: (context) => [
                for (final s in _minDurationChoices)
                  PopupMenuItem(
                    value: s,
                    child: Text(
                      s == 0 ? l10n.minDurationOff : l10n.minDurationValue(s),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(l10n.excludedFolders),
            subtitle: Text(
              l10n.excludedFoldersSummary(settings.excludedFolders.length),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _ExcludedFoldersPage()),
            ),
          ),
          section(l10n.settingsPlayback),
          ListTile(
            leading: const Icon(Icons.navigation_outlined),
            title: Text(l10n.duckLevel),
            subtitle: Slider(
              min: 0.1,
              max: 0.5,
              divisions: 4,
              value: settings.duckLevel,
              label: l10n.percent((settings.duckLevel * 100).round()),
              onChanged: settings.pauseOnDuck ? null : notifier.setDuckLevel,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pause_circle_outline),
            title: Text(l10n.pauseOnDuck),
            subtitle: Text(l10n.pauseOnDuckSubtitle),
            value: settings.pauseOnDuck,
            onChanged: notifier.setPauseOnDuck,
          ),
          ListTile(
            leading: const Icon(Icons.equalizer),
            title: Text(l10n.equalizer),
            subtitle: Text(
              settings.eqEnabled
                  ? eqPresetName(l10n, EqPreset.matching(settings.eqGains))
                  : l10n.off,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const EqualizerPage())),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.directions_car_outlined),
            title: Text(l10n.drivingMode),
            subtitle: Text(l10n.drivingModeSubtitle),
            value: settings.drivingMode,
            onChanged: notifier.setDrivingMode,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 「已分析 120 / 275 首」與進度條；選單可以重新分析全部。
class _AnalysisProgressTile extends ConsumerWidget {
  const _AnalysisProgressTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (done, total) = ref.watch(analysisProgressProvider);
    final running = ref.watch(analysisRunningProvider).value ?? false;
    return ListTile(
      leading: const Icon(Icons.analytics_outlined),
      title: Text(l10n.analysisProgress),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analysisProgressValue(done, total) +
                (running && done < total ? ' · ${l10n.analysisRunning}' : ''),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: total == 0 ? 0 : done / total),
        ],
      ),
      trailing: PopupMenuButton<void Function()>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: () => ref.read(loudnessProvider).reanalyzeAll(),
            child: Text(l10n.reanalyzeAll),
          ),
        ],
      ),
    );
  }
}

/// 列出所有有音樂的資料夾（包含已排除的），用開關決定要不要排除。
class _ExcludedFoldersPage extends ConsumerWidget {
  const _ExcludedFoldersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(allFoldersProvider);
    final excluded = ref.watch(settingsProvider).excludedFolders;
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.excludedFolders)),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, i) {
          final folder = folders[i];
          return CheckboxListTile(
            title: Text(folder.name),
            subtitle: Text(
              '${context.l10n.songCount(folder.songs.length)} · ${folder.path}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            value: excluded.contains(folder.path),
            onChanged: (v) =>
                notifier.setFolderExcluded(folder.path, v ?? false),
          );
        },
      ),
    );
  }
}
