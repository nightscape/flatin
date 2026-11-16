import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/stored_settings.dart';
import 'support/latin_course.dart';

FilterChip _chip(WidgetTester tester, String key) =>
    tester.widget<FilterChip>(find.byKey(Key(key)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a word chip that is on is not crossed out', (tester) async {
    await openSettingsWith(
      tester,
      Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(1, latinLastLesson),
        forcedOnWords: {'rosa'},
      ).toJson(),
    );

    final chip = _chip(tester, 'kursstand.word.rosa');
    expect(chip.selected, isTrue);
    expect(chip.labelStyle!.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('a topic chip that is on is not crossed out', (tester) async {
    final topic = (await loadCurriculum(latinCourse.books)).courseTopics.first;
    await openSettingsWith(
      tester,
      Settings(
        lastLesson: latinLastLesson,
        forcedOnTopics: {topic.key},
      ).toJson(),
    );

    final chip = _chip(tester, 'kursstand.topic.${topic.key}');
    expect(chip.selected, isTrue);
    expect(chip.labelStyle!.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('a word chip that is off inside the range is crossed out', (
    tester,
  ) async {
    await openSettingsWith(
      tester,
      Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(1, latinLastLesson),
        deselectedWords: {'rosa'},
      ).toJson(),
    );

    final chip = _chip(tester, 'kursstand.word.rosa');
    expect(chip.selected, isFalse);
    expect(chip.labelStyle!.decoration, TextDecoration.lineThrough);
  });

  testWidgets('a topic chip that is off inside the range is crossed out', (
    tester,
  ) async {
    final topic = (await loadCurriculum(latinCourse.books)).courseTopics.first;
    await openSettingsWith(
      tester,
      Settings(
        lastLesson: latinLastLesson,
        deselectedTopics: {topic.key},
      ).toJson(),
    );

    final chip = _chip(tester, 'kursstand.topic.${topic.key}');
    expect(chip.selected, isFalse);
    expect(chip.labelStyle!.decoration, TextDecoration.lineThrough);
  });
}
