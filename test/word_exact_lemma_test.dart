import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';
import 'support/stored_settings.dart';

/// The word sets of the stored v2 format dropped the macrons, so one stored
/// word stood for every lemma that spells it the same without them.
Map<String, dynamic> _v2({
  List<String> deselected = const [],
  List<String> forcedOn = const [],
}) => {
  settingsVersionField: 2,
  'disabledForms': <String, dynamic>{},
  'disabledTypes': <String, dynamic>{},
  'inputStrategyIds': <String, String>{},
  'deselectedWords': deselected,
  'forcedOnWords': forcedOn,
};

Finder _wordRow(String lemma) => find.byKey(Key('word.$lemma'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a stored word switches off every lemma that shares its letters',
    () async {
      final lessons = await loadLessonData(lessonDataAssets);
      final lemmas = lessons.lessonWords.values.expand((words) => words);

      final converted = convertSettingsV3(
        _v2(deselected: ['hic'], forcedOn: ['parere']),
        lemmas,
      );

      expect(converted['deselectedWords'], containsAll(['hic', 'hīc']));
      expect(converted['forcedOnWords'], containsAll(['parere', 'pārēre']));
      expect(converted[settingsVersionField], settingsVersion);
      // A word the lessons no longer list keeps the learner's choice.
      expect(
        convertSettingsV3(
          _v2(deselected: ['obsoletum']),
          lemmas,
        )['deselectedWords'],
        ['obsoletum'],
      );
    },
  );

  test('converting an already converted store changes nothing', () async {
    final lessons = await loadLessonData(lessonDataAssets);
    final lemmas = lessons.lessonWords.values.expand((words) => words);

    final once = convertSettingsV3(_v2(deselected: ['hic']), lemmas);
    expect(convertSettingsV3(once, lemmas), same(once));
  });

  testWidgets('the app reads a v2 store as both lemmas switched off', (
    tester,
  ) async {
    await openSettingsWith(tester, _v2(deselected: ['hic']), page: 'words');

    final stored = await storedSettings();
    expect(stored[settingsVersionField], settingsVersion);
    expect(stored['deselectedWords'], containsAll(['hic', 'hīc']));

    // A second run of the app finds the store converted and leaves it alone.
    await tester.pumpWidget(const SizedBox());
    await openSettingsWith(tester, stored, page: 'words');
    expect(await storedSettings(), stored);
  });

  testWidgets('two lemmas that differ only in macrons get a row each', (
    tester,
  ) async {
    await openSettingsWith(tester, _v2(), page: 'words');
    await tester.enterText(find.byKey(const Key('words.search')), 'parere');
    await tester.pumpAndSettle();

    expect(_wordRow('parere'), findsOneWidget);
    expect(_wordRow('pārēre'), findsOneWidget);
    expect(isChecked(tester, _wordRow('parere')), isTrue);
    expect(isChecked(tester, _wordRow('pārēre')), isTrue);

    await tester.tap(_wordRow('pārēre'));
    await tester.pumpAndSettle();

    expect(isChecked(tester, _wordRow('pārēre')), isFalse);
    expect(isChecked(tester, _wordRow('parere')), isTrue);
    expect((await storedSettings())['deselectedWords'], ['pārēre']);
  });

  test(
    'practice switches off only the macron or only the plain spelling that was stored',
    () async {
      final items = await loadAllPracticeItems();
      final parere = items.singleWhere((item) => item.lemma == 'parere');
      final withMacrons = items.singleWhere((item) => item.lemma == 'pārēre');

      Future<CourseFilter> filterWith(Set<String> deselected) async {
        seedSettings(Settings(deselectedWords: deselected));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        return container.read(courseFilterProvider.future);
      }

      final macronOff = await filterWith({'pārēre'});
      expect(macronOff.wordPracticed(withMacrons), isFalse);
      expect(macronOff.wordPracticed(parere), isTrue);

      final plainOff = await filterWith({'parere'});
      expect(plainOff.wordPracticed(parere), isFalse);
      expect(plainOff.wordPracticed(withMacrons), isTrue);
    },
  );
}
