import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';

import 'support/test_axes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deselected forms, types and words stay off after a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final lessons = await loadLessonData(lessonDataAsset);
    final word = normalizeDiacritics(lessons.lessonWords[lessons.lessonNames.first]!.first);

    final first = ProviderContainer();
    await first.read(settingsProvider.future);
    final notifier = first.read(settingsProvider.notifier);
    await notifier.toggleForm('nouns', 'genitive_singular');
    await notifier.toggleType('nouns', 'A-Deklination');
    await notifier.toggleWord(word);
    first.dispose();

    final second = ProviderContainer();
    final loaded = await second.read(settingsProvider.future);
    expect(
      loaded.isFormEnabled('nouns', 'genitive_singular', nounLabel('gen', 'sg')),
      isFalse,
    );
    expect(loaded.isTypeEnabled('nouns', 'A-Deklination'), isFalse);
    expect(loaded.isWordSelected(word), isFalse);
    // Entries that appear in the YAML later are not in the stored disabled
    // sets, so they are on.
    expect(
      loaded.isFormEnabled('nouns', 'brand_new_form', nounLabel('nom', 'pl')),
      isTrue,
    );
    expect(loaded.isTypeEnabled('nouns', 'Brand-New-Deklination'), isTrue);
    expect(loaded.isWordSelected('brandnovus'), isTrue);
    second.dispose();
  });

  test('settings stored as enabled sets convert to disabled sets', () async {
    final metadata = await getFormMetadata('lib/data/latin_nouns.yaml');
    final lessons = await loadLessonData(lessonDataAsset);
    final allWords = lessons.lessonNames
        .expand((name) => lessons.lessonWords[name]!)
        .map(normalizeDiacritics)
        .toList();

    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode({
        'enabledForms': {
          'nouns': [metadata.formOrder.first],
        },
        'enabledTypes': {
          'nouns': [metadata.availableTypes.first],
        },
        'inputStrategyIds': {'nouns': 'text_field'},
        'selectedWords': [allWords.first],
      }),
    });

    final container = ProviderContainer();
    final loaded = await container.read(settingsProvider.future);

    expect(
      loaded.disabledForms['nouns'],
      metadata.formOrder.skip(1).toSet(),
    );
    expect(
      loaded.disabledTypes['nouns'],
      metadata.availableTypes.skip(1).toSet(),
    );
    expect(loaded.deselectedWords, allWords.skip(1).toSet());
    expect(loaded.getInputStrategyId('nouns'), 'text_field');
    // Nothing was stored for verbs, so verbs stay fully enabled.
    expect(loaded.disabledForms['verbs'], isNull);
    expect(loaded.isTypeEnabled('verbs', 'A-Konjugation'), isTrue);
    container.dispose();
  });

  test('conversion leaves words outside the lessons enabled', () async {
    final lessons = await loadLessonData(lessonDataAsset);
    final lessonWords = lessons.lessonNames
        .expand((name) => lessons.lessonWords[name]!)
        .map(normalizeDiacritics)
        .toList();

    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode({
        'selectedWords': [lessonWords.first],
      }),
    });

    final container = ProviderContainer();
    final outside = await container.read(wordsOutsideLessonsProvider.future);
    final loaded = await container.read(settingsProvider.future);

    // The old format had no checkbox for these, so no user ever turned them
    // off.
    expect(outside, isNotEmpty);
    for (final word in outside) {
      expect(loaded.isWordSelected(normalizeDiacritics(word)), isTrue,
          reason: word);
    }
    expect(loaded.deselectedWords, lessonWords.skip(1).toSet());
    container.dispose();
  });
}
