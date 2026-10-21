import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

Exercise _shown(WidgetTester tester) {
  final screen = find.byType(ExerciseScreen);
  return screen.evaluate().isEmpty
      ? tester
            .widget<ExerciseMatchWidget>(find.byType(ExerciseMatchWidget))
            .exercise
      : tester.widget<ExerciseScreen>(screen).exercise;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _answerRight(WidgetTester tester, Exercise exercise) async {
  switch (exercise.answer) {
    case ChoiceAnswer(:final options, :final right):
      await _tap(tester, 'exercise.option.${options.indexOf(right)}');
    case TypedAnswer(:final expected):
      await tester.enterText(
        find.byKey(const Key('exercise.input')),
        expected.text,
      );
      await _tap(tester, 'exercise.check.button');
    case MatchingAnswer(:final pairs):
      for (var i = 0; i < pairs.length; i++) {
        await _tap(tester, 'exercise.match.left.$i');
        await _tap(tester, 'exercise.match.right.$i');
      }
      await _tap(tester, 'exercise.check.button');
  }
}

void main() {
  testWidgets('the grammar entry starts an exercise, and its right answer '
      'reviews both cards and brings the next exercise', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      wrapInApp(
        const HomeScreen(),
        overrides: [exerciseRandomProvider.overrideWithValue(Random(139))],
      ),
    );
    await letItLoad(tester);

    await tester.tap(find.byKey(const Key('home.grammar.button')));
    await letItLoad(tester);
    final first = _shown(tester);
    await _answerRight(tester, first);
    expect(find.text('Correct'), findsOneWidget);
    await _tap(tester, 'exercise.next.button');
    await letItLoad(tester);

    final stored = await tester.runAsync(FsrsStorage.loadCards);
    for (final id in [first.wordCardId, first.grammarCardId]) {
      expect(stored![id]!.lastReview, isNotNull, reason: id);
    }
    expect(identical(_shown(tester), first), isFalse);
  });
}
