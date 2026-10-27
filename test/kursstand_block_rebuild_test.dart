import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/stored_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a range change rebuilds only the lesson blocks it changes', (
    tester,
  ) async {
    final lessons = await loadLessonData(bookAssets);
    String firstWordOf(int lesson) =>
        lessons.wordToLesson.entries.firstWhere((e) => e.value == lesson).key;
    final kept = firstWordOf(2), changed = firstWordOf(20);
    await openSettingsWith(
      tester,
      Settings(
        courseWords: LessonRange(1, 30),
        courseGrammar: LessonRange(1, 30),
      ).toJson(),
    );
    FilterChip chip(String lemma) =>
        tester.widget<FilterChip>(find.byKey(Key('kursstand.word.$lemma')));
    final (keptBefore, changedBefore) = (chip(kept), chip(changed));

    await dragRange(tester, words: true, to: LessonRange(1, 12));

    expect(chip(changed).selected, isNot(changedBefore.selected));
    expect(identical(chip(kept), keptBefore), isTrue);
  });
}
