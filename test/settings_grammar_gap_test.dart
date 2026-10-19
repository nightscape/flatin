import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

const _type = 'A-Deklination';
final _typeRow = find.byKey(const Key('type.nouns.$_type'));
final _genRow = formTile('nouns', 'gen.sg');
final _nomRow = formTile('nouns', 'nom.sg');

Future<void> _open(
  WidgetTester tester,
  Settings settings,
  Curriculum curriculum,
) =>
    openSettingsWith(
      tester,
      settings.toJson(),
      page: 'nouns',
      overrides: [curriculumProvider.overrideWith((ref) async => curriculum)],
    );

Future<void> _tap(WidgetTester tester, Finder row) async {
  await tester.tap(row);
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Finder _gapText(Finder row, String text) =>
    find.descendant(of: row, matching: find.text(text));

void main() {
  testWidgets('a type the course has not taught is greyed and a tap forces it on',
      (tester) async {
    final curriculum = await lateTypeCurriculum('nouns', _type, 32);
    await _open(tester, Settings(courseWords: LessonRange(1, 5)), curriculum);

    expect(_gapText(_typeRow, 'ab Lektion 32'), findsOneWidget);
    expect(titleColor(tester, _typeRow), isNot(Colors.black));
    expect(isChecked(tester, _typeRow), isFalse);

    await _tap(tester, _typeRow);

    expect(isChecked(tester, _typeRow), isTrue);
    expect((await storedSettings())['forcedOnTypes'], {
      'nouns': [_type],
    });
    expect(_gapText(_typeRow, 'ab Lektion 32'), findsNothing);
    expect(titleColor(tester, _typeRow), Colors.black,
        reason: 'a forced-on type is offered, so it is not greyed');
  });

  testWidgets('a form the course has not taught is greyed and a tap forces it on',
      (tester) async {
    final curriculum = await lateGenitiveCurriculum();
    await _open(tester, Settings(courseWords: LessonRange(1, 5)), curriculum);

    expect(titleColor(tester, _nomRow), Colors.black);
    expect(_gapText(_genRow, 'ab Lektion 30'), findsOneWidget);
    expect(titleColor(tester, _genRow), isNot(Colors.black));
    expect(isChecked(tester, _genRow), isFalse);

    await _tap(tester, _genRow);

    expect(isChecked(tester, _genRow), isTrue);
    expect((await storedSettings())['forcedOnForms'], {
      'nouns': ['gen.sg'],
    });
    expect(_gapText(_genRow, 'ab Lektion 30'), findsNothing);
    expect(titleColor(tester, _genRow), Colors.black,
        reason: 'a forced-on form is offered, so it is not greyed');
  });

  testWidgets('a form forced on stays offered and a tap switches it off',
      (tester) async {
    final curriculum = await lateGenitiveCurriculum();
    await _open(
      tester,
      Settings(courseWords: LessonRange(1, 5), forcedOnForms: {
        'nouns': {'gen.sg'},
      }),
      curriculum,
    );

    await _tap(tester, _genRow);

    expect(isChecked(tester, _genRow), isFalse);
    expect((await storedSettings())['forcedOnForms'], {'nouns': isEmpty});
  });
}
