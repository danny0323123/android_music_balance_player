import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/effects.dart';
import '../l10n/app_localizations.dart';
import '../state/settings.dart';
import 'common.dart';

String eqPresetName(AppLocalizations l10n, EqPreset? preset) =>
    switch (preset) {
      null => l10n.eqCustom,
      EqPreset.flat => l10n.eqFlat,
      EqPreset.bassBoost => l10n.eqBassBoost,
      EqPreset.trebleBoost => l10n.eqTrebleBoost,
      EqPreset.vocal => l10n.eqVocal,
      EqPreset.rock => l10n.eqRock,
      EqPreset.pop => l10n.eqPop,
      EqPreset.classical => l10n.eqClassical,
    };

String _frequencyLabel(int hz) => hz >= 1000 ? '${hz ~/ 1000}k' : '$hz';

class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final enabled = settings.eqEnabled;
    final current = EqPreset.matching(settings.eqGains);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.equalizer)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.eqEnable),
            value: enabled,
            onChanged: notifier.setEqEnabled,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in EqPreset.values)
                  ChoiceChip(
                    label: Text(eqPresetName(l10n, preset)),
                    selected: current == preset,
                    onSelected: enabled
                        ? (_) => notifier.setEqGains(preset.gains)
                        : null,
                  ),
                if (current == null)
                  ChoiceChip(
                    label: Text(l10n.eqCustom),
                    selected: true,
                    onSelected: null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (var i = 0; i < eqFrequencies.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _formatBandGain(settings.eqGains[i]),
                            style: textTheme.labelSmall,
                          ),
                          Expanded(
                            // 把橫的滑桿轉 90 度變成直的，上面是 +12、下面是 −12
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                min: -eqMaxGainDb,
                                max: eqMaxGainDb,
                                divisions: (eqMaxGainDb * 2).round(),
                                value: settings.eqGains[i],
                                onChanged: enabled
                                    ? (v) => notifier.setEqBand(i, v)
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            _frequencyLabel(eqFrequencies[i]),
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.eqHint, style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  static String _formatBandGain(double db) {
    final rounded = db.round();
    if (rounded == 0) return '0';
    return rounded > 0 ? '+$rounded' : '−${-rounded}';
  }
}
