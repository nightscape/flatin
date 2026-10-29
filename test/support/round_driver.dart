import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/screens/exercise_sort_widget.dart';

/// The task on screen, whether a single task or a matching one.
Exercise shown(WidgetTester tester) {
  final screen = find.byType(ExerciseScreen);
  final sort = find.byType(ExerciseSortWidget);
  return screen.evaluate().isNotEmpty
      ? tester.widget<ExerciseScreen>(screen).exercise
      : sort.evaluate().isNotEmpty
      ? tester.widget<ExerciseSortWidget>(sort).exercise
      : tester
            .widget<ExerciseMatchWidget>(find.byType(ExerciseMatchWidget))
            .exercise;
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
    case TypedAnswer(:final expected, :final accepted):
      final input = find.byKey(const Key('exercise.input'));
      if (tester.widget(input) is TextField) {
        await tester.enterText(input, right ? expected.text : 'xyz');
      } else {
        final options = dropdownOptions(tester);
        await choose(
          tester,
          right
              ? options.singleWhere((o) => norm(o) == norm(expected.text))
              : options.firstWhere(
                  (o) => !accepted.any((a) => norm(a) == norm(o)),
                ),
        );
      }
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
    case SortingAnswer(:final groups, :final forms, :final tick):
      for (final (i, (_, g)) in forms.indexed) {
        final given = right || i > 0 ? g : (g + 1) % groups.length;
        if (tick) {
          if (given == 0) await tap(tester, 'exercise.sort.form.$i');
        } else {
          final from = tester.getCenter(
            find.byKey(Key('exercise.sort.form.$i')),
          );
          final to = tester.getCenter(
            find.byKey(Key('exercise.sort.group.$given')),
          );
          await tester.dragFrom(from, to - from);
          await tester.pumpAndSettle();
        }
      }
      await tap(tester, 'exercise.check.button');
  }
  await tap(tester, 'exercise.next.button');
}

/// The options of the exercise's input dropdown.
List<String> dropdownOptions(WidgetTester tester) => [
  for (final item
      in tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: find.byKey(const Key('exercise.input')),
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!)
    item.value!,
];

/// Opens the exercise's input dropdown and picks [option].
Future<void> choose(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(const Key('exercise.input')));
  await tester.pumpAndSettle();
  final menu = find.byType(Scrollable).last;
  final item = find.descendant(of: menu, matching: find.text(option));
  await tester.scrollUntilVisible(item, 100, scrollable: menu);
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}
