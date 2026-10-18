import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

Finder _text(String key) => find.byKey(Key(key));

String _shown(WidgetTester tester, String key) =>
    tester.widget<Text>(_text(key)).data!;

Future<void> _move(
  WidgetTester tester,
  String slider,
  int from,
  int to,
) async {
  tester
      .widget<RangeSlider>(_text(slider))
      .onChanged!(RangeValues(from.toDouble(), to.toDouble()));
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _open(
  WidgetTester tester,
  Settings settings, {
  String? page,
  Curriculum? curriculum,
}) =>
    openSettingsWith(
      tester,
      settings.toJson(),
      page: page,
      overrides: [
        if (curriculum != null)
          curriculumProvider.overrideWith((ref) async => curriculum),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card shows two sliders, the toggle, the summary and reset',
      (tester) async {
    await _open(tester, Settings());

    expect(_text('kursstand.words.slider'), findsOneWidget);
    expect(_text('kursstand.grammar.slider'), findsOneWidget);
    expect(_text('kursstand.follow'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_text('kursstand.follow')).value,
        isTrue);
    expect(_shown(tester, 'kursstand.summary'),
        matches(r'^\d+ Wörter, \d+ Nomenformen, \d+ Verbformen$'));
    expect(find.text('Auf Kursstand zurücksetzen'), findsOneWidget);
    expect(_shown(tester, 'kursstand.words.label'), 'L1 (Band 1) - L40 (Band 2)');
  });

  testWidgets('the grammar slider follows the word slider while linked',
      (tester) async {
    await _open(tester, Settings());

    await _move(tester, 'kursstand.words.slider', 21, 23);
    expect(_shown(tester, 'kursstand.words.label'), 'L21 (Band 2) - L23');
    expect(_shown(tester, 'kursstand.grammar.label'), 'L1 (Band 1) - L23 (Band 2)');
    expect(tester.widget<RangeSlider>(_text('kursstand.grammar.slider')).onChanged,
        isNull);
  });

  testWidgets('the grammar slider stays when unlinked', (tester) async {
    await _open(tester, Settings());

    await tester.tap(_text('kursstand.follow'));
    await tester.pumpAndSettle();
    await _move(tester, 'kursstand.words.slider', 1, 5);
    expect(_shown(tester, 'kursstand.words.label'), 'L1 (Band 1) - L5');
    expect(_shown(tester, 'kursstand.grammar.label'), 'L1 (Band 1) - später');

    await _move(tester, 'kursstand.grammar.slider', 3, 12);
    expect(_shown(tester, 'kursstand.grammar.label'), 'L3 (Band 1) - L12');
  });

  testWidgets('the top stop of the grammar slider reads später',
      (tester) async {
    await _open(tester, Settings());

    expect(_shown(tester, 'kursstand.grammar.label'), endsWith('später'));
    expect(
      tester
          .widget<RangeSlider>(_text('kursstand.grammar.slider'))
          .labels!
          .end,
      'später',
    );
  });

  testWidgets('a word outside the word range is greyed and a tap forces it on',
      (tester) async {
    final lessons = await loadLessonData(lessonDataAssets);
    final inRange = (await loadAllPracticeItems())
        .firstWhere((i) => lessons.lessonNumberOf(i) == 21);

    await _open(tester, Settings(courseWords: LessonRange(21, 23)),
        page: 'words');

    expect(isChecked(tester, _text('word.rosa')), isFalse);
    expect(
      find.descendant(
          of: _text('word.rosa'), matching: find.text('außerhalb des Bereichs')),
      findsOneWidget,
    );
    expect(
      titleColor(tester, _text('word.${normalizeDiacritics(inRange.lemma)}')),
      Colors.black,
      reason: 'a word the course has reached must not look greyed',
    );
    expect(titleColor(tester, _text('word.rosa')), isNot(Colors.black),
        reason: 'an out-of-range word row must look greyed');

    await tester.tap(_text('word.rosa'));
    await tester.pumpAndSettle();
    await letItLoad(tester);

    expect(isChecked(tester, _text('word.rosa')), isTrue);
    expect((await storedSettings())['forcedOnWords'], ['rosa']);
  });

  testWidgets('a word whose type is taught later says from which lesson',
      (tester) async {
    final lessons = await loadLessonData(lessonDataAssets);
    final item = (await loadAllPracticeItems())
        .firstWhere((i) => lessons.lessonNumberOf(i) == 21);
    final curriculum = await lateTypeCurriculum(item.dataFileId, item.type, 32);

    await _open(tester, Settings(courseWords: LessonRange(21, 23)),
        page: 'words', curriculum: curriculum);

    final tile = _text('word.${normalizeDiacritics(item.lemma)}');
    expect(find.descendant(of: tile, matching: find.text('ab Lektion 32')),
        findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('außerhalb des Bereichs')),
        findsNothing);
    expect(titleColor(tester, tile), isNot(Colors.black),
        reason: 'a word whose type is taught later must look greyed');
  });

  testWidgets('reset clears the overrides and keeps the ranges',
      (tester) async {
    await _open(
      tester,
      Settings(
        courseWords: LessonRange(1, 5),
        forcedOnWords: {'rosa'},
        deselectedWords: {'servus'},
      ),
    );

    await tester.tap(_text('kursstand.reset'));
    await tester.pumpAndSettle();
    await letItLoad(tester);

    final stored = await storedSettings();
    expect(stored['forcedOnWords'], isEmpty);
    expect(stored['deselectedWords'], isEmpty);
    expect(stored['courseWords'], LessonRange(1, 5).toJson());
  });

  testWidgets('overrides survive a slider move', (tester) async {
    await _open(
      tester,
      Settings(forcedOnWords: {'rosa'}, deselectedWords: {'servus'}),
    );

    await _move(tester, 'kursstand.words.slider', 1, 12);

    final stored = await storedSettings();
    expect(stored['forcedOnWords'], ['rosa']);
    expect(stored['deselectedWords'], ['servus']);
    expect(stored['courseWords'], LessonRange(1, 12).toJson());
  });

  testWidgets('the tiles open the detail pages', (tester) async {
    await _open(tester, Settings());

    for (final page in ['words', 'nouns', 'verbs', 'input']) {
      await openSettingsPage(tester, page);
      expect(_text('settings.${page == 'input' ? 'input' : page}.title'),
          findsOneWidget,
          reason: page);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
