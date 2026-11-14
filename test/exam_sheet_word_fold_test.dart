import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/course_providers.dart';
import 'support/gen_exam.dart';
import 'support/key_echo_app.dart';
import 'support/latin_course.dart';
import 'support/word_classification_harness.dart';

const _wordPrefix = 'exam.sheet.lesson.word.';

/// Lesson lists that spell one word in two ways that differ only in quantity
/// marks, each in a drawn lesson, and a token spelling that matches neither
/// exactly but folds to both.
(LessonData, String, Set<int>) _foldGroup(Random r) {
  const groups = [
    ('pārēre', 'parere', ['pārere', 'parēre']),
    ('līberī', 'liberi', ['līberi', 'liberī']),
    ('ōrāre', 'orare', ['ōrare', 'orāre']),
  ];
  final (a, b, tokens) = groups[r.nextInt(groups.length)];
  final la = 1 + r.nextInt(6), lb = 1 + r.nextInt(6);
  final lessons = LessonData(
    wordToLesson: {a: la, b: lb},
    lessonWords: {
      for (final l in {la, lb}) l: [if (l == la) a, if (l == lb) b],
    },
    bookByLesson: {
      for (final l in {la, lb}) l: 1,
    },
    books: const ['b'],
  );
  return (lessons, tokens[r.nextInt(tokens.length)], {la, lb});
}

void main() {
  testWidgets('the sheet of a token that folds to several list words shows '
      'one word line per distinct lesson', (tester) async {
    final curriculum = (await tester.runAsync(
      () => curriculumOf([
        for (final b in latinCourse.books) File(b).readAsStringSync(),
      ]),
    ))!;
    var several = 0;
    for (var seed = 0; seed < 20; seed++) {
      final r = Random(seed);
      final (lessons, lemma, expected) = _foldGroup(r);
      final exam = parseExam(
        jsonEncode(
          ExamGen(
            r,
            nouns: [lemma],
            adjectives: [lemma],
            verbs: [lemma],
            participles: [lemma],
          ).exam(),
        ),
        latinLang,
      );
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1200, 60000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInKeyEchoAppWith(
          ExamScreen(exam: exam),
          overrides: [
            lessonDataProvider.overrideWith((ref) => lessons),
            curriculumProvider.overrideWith((ref) => curriculum),
          ],
        ),
      );
      await letItLoad(tester);
      final tokens = [
        for (final s in exam.saetze)
          for (final t in s.tokens)
            if (t case final WordToken w when w.lemma == lemma) w,
      ];
      if (tokens.isEmpty) continue;
      await tester.tap(find.byKey(Key('exam.token.${tokens.first.id}')));
      await tester.pump();
      await letItLoad(tester);
      final shown = {
        for (final t in tester.widgetList<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(_wordPrefix),
          ),
        ))
          int.parse(
            (t.key as ValueKey<String>).value.substring(_wordPrefix.length),
          ),
      };
      expect(shown, expected, reason: 'seed $seed, $lemma');
      if (expected.length > 1) several++;
    }
    expect(several, greaterThan(0));
  });
}
