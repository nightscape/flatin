import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/exam_units.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_settings.dart';

const _cases = 300;
const _providerCases = 12;

/// [settings] as a store of version 4: without the exam settings.
Json _v4(Settings settings) => jsonDecode(
  jsonEncode({
    ...settings.toJson()
      ..remove('uebersetzungseinheit')
      ..remove('punkteAnzeige'),
    settingsVersionField: 4,
  }),
);

/// The fixed states the seeded loop runs first.
final _static = <String, Settings Function()>{
  'defaults': Settings.new,
  'satz, points on': () => Settings(
    uebersetzungseinheit: Uebersetzungseinheit.satz,
    punkteAnzeige: true,
  ),
};

Iterable<(String, Settings)> _drawn(int count) sync* {
  for (final MapEntry(:key, :value) in _static.entries) {
    yield (key, value());
  }
  for (var seed = 1; seed <= count; seed++) {
    yield ('seed $seed', drawSettings(Random(seed), exam: true));
  }
}

/// [settings] with the exam settings at their defaults.
Json _withDefaults(Settings settings) => settings
    .copyWith(
      uebersetzungseinheit: Uebersetzungseinheit.teilsatz,
      punkteAnzeige: false,
    )
    .toJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('[E] a version 4 store converts to the exam defaults (clause, points '
      'off), keeps every other field, and round-trips', () {
    for (final (name, drawn) in _drawn(_cases)) {
      final converted = Settings.fromJson(convertSettingsV5(_v4(drawn)));
      expect(
        converted.uebersetzungseinheit,
        Uebersetzungseinheit.teilsatz,
        reason: name,
      );
      expect(converted.punkteAnzeige, isFalse, reason: name);
      expect(converted.toJson(), _withDefaults(drawn), reason: name);
      expect(
        Settings.fromJson(jsonDecode(jsonEncode(drawn.toJson()))).toJson(),
        drawn.toJson(),
        reason: '$name: the exam settings round-trip',
      );
    }
  });

  test('[E] the app loads a version 4 store with the exam defaults and '
      'stores it as the current version', () async {
    for (final (name, drawn) in _drawn(_providerCases)) {
      SharedPreferences.setMockInitialValues({
        'practice_settings': jsonEncode(_v4(drawn)),
      });
      final container = ProviderContainer();
      final loaded = await container.read(settingsProvider.future);
      container.dispose();
      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('practice_settings')!) as Json;
      expect(loaded.toJson(), _withDefaults(drawn), reason: name);
      expect(stored, loaded.toJson(), reason: name);
      expect(stored[settingsVersionField], settingsVersion, reason: name);
    }
  });
}
