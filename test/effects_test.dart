import 'package:flutter_test/flutter_test.dart';
import 'package:music_balance/audio/effects.dart';
import 'package:music_balance/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every preset has one gain per band, within range', () {
    for (final preset in EqPreset.values) {
      expect(preset.gains, hasLength(eqFrequencies.length), reason: '$preset');
      for (final g in preset.gains) {
        expect(g.abs(), lessThanOrEqualTo(eqMaxGainDb), reason: '$preset');
      }
    }
  });

  test('presets are distinct so matching is unambiguous', () {
    for (final preset in EqPreset.values) {
      expect(EqPreset.matching(preset.gains), preset);
    }
  });

  test('a moved slider is reported as custom', () {
    final gains = [...EqPreset.rock.gains]..[3] = 5;
    expect(EqPreset.matching(gains), isNull);
  });

  group('eqGainsFromPrefs', () {
    Future<SharedPreferences> prefs(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test('defaults to flat', () async {
      expect(eqGainsFromPrefs(await prefs({})), EqPreset.flat.gains);
    });

    test('reads saved gains', () async {
      final saved = [for (final g in EqPreset.vocal.gains) '$g'];
      expect(
        eqGainsFromPrefs(await prefs({SettingsKeys.eqGains: saved})),
        EqPreset.vocal.gains,
      );
    });

    test(
      'falls back to flat when the saved list has the wrong length',
      () async {
        expect(
          eqGainsFromPrefs(
            await prefs({
              SettingsKeys.eqGains: ['1', '2', '3'],
            }),
          ),
          EqPreset.flat.gains,
        );
      },
    );
  });
}
