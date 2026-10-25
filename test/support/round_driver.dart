import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

/// The task on screen, whether a single task or a matching one.
Exercise shown(WidgetTester tester) {
  final screen = find.byType(ExerciseScreen);
  return screen.evaluate().isEmpty
      ? tester
            .widget<ExerciseMatchWidget>(find.byType(ExerciseMatchWidget))
            .exercise
      : tester.widget<ExerciseScreen>(screen).exercise;
}

Future<void> tap(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}

/// Answers [exercise] through the UI and moves on to the next task.
Future<void> answer(
  WidgetTester tester,
  Exercise exercise, {
  required bool right,
}) async {
  switch (exercise.answer) {
    case ChoiceAnswer(:final options, right: final rightOption):
      final index = right
          ? options.indexOf(rightOption)
          : options.indexWhere((o) => !identical(o, rightOption));
      await tap(tester, 'exercise.option.$index');
    case TypedAnswer(:final expected):
      await tester.enterText(
        find.byKey(const Key('exercise.input')),
        right ? expected.text : 'xyz',
      );
      await tap(tester, 'exercise.check.button');
    case MatchingAnswer(:final pairs):
      for (var i = 0; i < pairs.length; i++) {
        await tap(tester, 'exercise.match.left.$i');
        await tap(
          tester,
          'exercise.match.right.${right ? i : (i + 1) % pairs.length}',
        );
      }
      await tap(tester, 'exercise.check.button');
  }
  await tap(tester, 'exercise.next.button');
}
