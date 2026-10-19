import 'dart:convert';

import 'package:latin_practice/data/asset_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deselected forms, types and words stay off after a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final lessons = await loadLessonData(lessonDataAssets);
    final word = normalizeDiacritics(lessons.lessonWords[lessons.lessonNames.first]!.first);

    final first = ProviderContainer();
    await first.read(settingsProvider.future);
    final notifier = first.read(settingsProvider.notifier);
    await notifier.toggleForm('nouns', 'gen.sg', inRange: true);
    await notifier.toggleType('nouns', 'A-Deklination', inRange: true);
    await notifier.toggleWord(word, inRange: true);
    first.dispose();

    final second = ProviderContainer();
    final loaded = await second.read(settingsProvider.future);
    expect(
      loaded.isFormSwitchedOn('nouns', 'gen.sg'),
      isFalse,
    );
    expect(loaded.isTypeEnabled('nouns', 'A-Deklination'), isFalse);
    expect(loaded.isWordSelected(word), isFalse);
    // Entries that appear in the YAML later are not in the stored disabled
    // sets, so they are on.
    expect(
      loaded.isFormSwitchedOn('nouns', 'nom.pl'),
      isTrue,
    );
    expect(loaded.isTypeEnabled('nouns', 'Brand-New-Deklination'), isTrue);
    expect(loaded.isWordSelected('brandnovus'), isTrue);
    second.dispose();
  });

  test('the notifier stores what the course says about the entry, not a '
      'constant', () async {
    final stored = Settings(courseWords: LessonRange(1, 20));
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode({
        settingsVersionField: settingsVersion,
        ...stored.toJson(),
      }),
    });

    final container = ProviderContainer();
    await container.read(settingsProvider.future);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.toggleWord('nauta', inRange: false);
    await notifier.toggleType('nouns', 'U-Deklination', inRange: false);
    await notifier.toggleForm('nouns', 'gen.sg', inRange: false);
    container.dispose();

    final reloaded = ProviderContainer();
    final loaded = await reloaded.read(settingsProvider.future);

    expect(loaded.courseWords, LessonRange(1, 20));
    expect(loaded.overrideOfWord('nauta'), Override.forcedOn);
    expect(loaded.overrideOfType('nouns', 'U-Deklination'), Override.forcedOn);
    expect(loaded.overrideOfForm('nouns', 'gen.sg'), Override.forcedOn);
    expect(loaded.deselectedWords, isEmpty);
    reloaded.dispose();
  });

  test('settings stored as enabled sets convert to disabled sets', () async {
    final map = MigrationMap.parse(
      await loadAssetText('lib/data/migration_v2.yaml'),
    );
    final oldType = map.types['nouns']!.keys.first;
    final newType = map.types['nouns']![oldType]!;
    final otherType = map.types['nouns']!.values.firstWhere((t) => t != newType);
    final lessons = await loadLessonData(lessonDataAssets);
    final allWords = lessons.lessonNames
        .expand((name) => lessons.lessonWords[name]!)
        .map(normalizeDiacritics)
        .toList();

    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode({
        'enabledForms': {
          'nouns': ['nominative_singular'],
        },
        'enabledTypes': {
          'nouns': [oldType],
        },
        'inputStrategyIds': {'nouns': 'text_field'},
        'selectedWords': [allWords.first],
      }),
    });

    final container = ProviderContainer();
    final loaded = await container.read(settingsProvider.future);

    final stillOn = map.formKeys['nouns']!['nominative_singular']!.toSet();
    final universe = [
      for (final old in map.v0FormUniverse['nouns']!)
        ...map.formKeys['nouns']![old]!,
    ];
    expect(
      loaded.disabledForms['nouns'],
      universe.where((k) => !stillOn.contains(k)).toSet(),
    );
    expect(loaded.isTypeEnabled('nouns', newType), isTrue);
    expect(loaded.isTypeEnabled('nouns', otherType), isFalse);
    expect(loaded.getInputStrategyId('nouns'), 'text_field');
    // Nothing was stored for verbs, so verbs stay fully enabled.
    expect(loaded.disabledForms['verbs'], isEmpty);
    expect(loaded.isTypeEnabled('verbs', 'A-Konjugation'), isTrue);
    container.dispose();
  });

  test('conversion deselects every lesson word the old format left out',
      () async {
    final lessons = await loadLessonData(lessonDataAssets);
    final lessonWords =
        lessons.lessonNames.expand((name) => lessons.lessonWords[name]!);

    // The old format stored the words without their macrons; what comes back
    // is the exact lemma of each.
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode({
        'selectedWords': [normalizeDiacritics(lessonWords.first)],
      }),
    });

    final container = ProviderContainer();
    final loaded = await container.read(settingsProvider.future);

    expect(loaded.deselectedWords, lessonWords.skip(1).toSet());
    container.dispose();
  });
}
