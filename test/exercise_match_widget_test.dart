import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _bundle = 'ind.praes.akt';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
  });

  final generator = generatorFor(ExerciseKind.zuordnen, exerciseGenerators);
  Exercise build(PracticeItem word, GrammarBundle bundle) => generator.build(
    word,
    bundle,
    fakeExerciseContext(unlocked: {bundle}, pool: [word]),
    Random(3),
  );

  MatchingAnswer answerOf(Exercise e) => e.answer as MatchingAnswer;

  group('attribution', () {
    late Exercise exercise;
    late List<(FormOption, FormOption)> right;
    setUp(() {
      exercise = build(vocare, _bundle);
      right = answerOf(exercise).pairs;
    });

    test('all pairs right: Good/Good', () {
      expect(attribute(vocare, exercise, MatchedPairs(right)), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('two German texts swapped: the word is known, the grammar not', () {
      final swapped = [
        (right[0].$1, right[1].$2),
        (right[1].$1, right[0].$2),
        right[2],
        right[3],
      ];
      expect(attribute(vocare, exercise, MatchedPairs(swapped)), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    test('a German text of another word blames the word only', () {
      final foreign = FormOption(
        text: 'anderes@${right[0].$1.formKey}',
        formKey: right[0].$1.formKey,
        lexemeId: 'verbs:dicere',
      );
      final wrong = [(right[0].$1, foreign), ...right.skip(1)];
      expect(attribute(vocare, exercise, MatchedPairs(wrong)), (
        word: Rating.again,
        grammar: Rating.good,
      ));
    });
  });

  group('widget', () {
    Future<List<MatchedPairs>> pump(
      WidgetTester tester,
      Exercise exercise, {
      String language = 'de',
      String? title,
    }) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final responses = <MatchedPairs>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseMatchWidget(
            word: vocare,
            exercise: exercise,
            title: title,
            onResponse: responses.add,
          ),
          forcedLocale: Locale(language),
        ),
      );
      await tester.pumpAndSettle();
      return responses;
    }

    Future<void> tapNext(WidgetTester tester) async {
      final next = find.byKey(const Key('exercise.next.button'));
      await tester.scrollUntilVisible(
        next,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(next);
    }

    Future<void> pair(WidgetTester tester, int left, int right) async {
      await tester.tap(find.byKey(Key('exercise.match.left.$left')));
      await tester.pump();
      await tester.tap(find.byKey(Key('exercise.match.right.$right')));
      await tester.pump();
    }

    testWidgets('a given title replaces the standard one', (tester) async {
      await pump(tester, build(vocare, _bundle), title: 'Aufgabe 3 von 10');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Aufgabe 3 von 10'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no title shows the standard title of the locale', (
      tester,
    ) async {
      await pump(tester, build(vocare, _bundle));

      final standard =
          (jsonDecode(
                File('assets/flutter_i18n/de.json').readAsStringSync(),
              )['exercise']['screen']['title']
              as String);
      expect(standard, isNotEmpty);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(standard)),
        findsOneWidget,
      );
    });

    testWidgets('right pairs say right and report the very options', (
      tester,
    ) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      final responses = await pump(tester, exercise);

      expect(find.byKey(const Key('exercise.check.button')), findsNothing);
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();

      expect(find.text('Richtig'), findsOneWidget);
      await tapNext(tester);
      await tapNext(tester);
      expect(responses, hasLength(1));
      expect(attribute(vocare, exercise, responses.single), (
        word: Rating.good,
        grammar: Rating.good,
      ));
      for (final (latin, german) in right) {
        expect(
          responses.single.pairs.any(
            (p) => identical(p.$1, latin) && identical(p.$2, german),
          ),
          isTrue,
        );
      }
    });

    testWidgets('swapped pairs say wrong and name the right pairs', (
      tester,
    ) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      final responses = await pump(tester, exercise);

      await pair(tester, 0, 1);
      await pair(tester, 1, 0);
      await pair(tester, 2, 2);
      await pair(tester, 3, 3);
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('So heißt es: ${right[0].$1.text} = '),
        findsOneWidget,
      );
      final feedback = find.byKey(const Key('exercise.feedback'));
      expect(
        tester.widget<Text>(feedback).style!.color,
        Theme.of(tester.element(feedback)).textTheme.titleMedium!.color,
        reason: 'a wrong answer is named in the neutral text colour',
      );
      await tapNext(tester);
      expect(attribute(vocare, exercise, responses.single), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    Future<void> seenLine(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(text), findsOneWidget);
    }

    String labelOf(PracticeItem word, FormKey key) =>
        describeLabels([word.formLabels[word.formOrder.indexOf(key)]]);

    testWidgets('a wrong pairing labels every pair', (tester) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      await pump(tester, exercise);
      await pair(tester, 0, 1);
      await pair(tester, 1, 0);
      await pair(tester, 2, 2);
      await pair(tester, 3, 3);
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      for (final (latin, _) in right) {
        await seenLine(
          tester,
          '${latin.text} – ${labelOf(vocare, latin.formKey)}',
        );
      }
    });

    testWidgets('tapping a paired Latin form releases it', (tester) async {
      await pump(tester, build(vocare, _bundle));
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      expect(find.byKey(const Key('exercise.check.button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.match.left.0')));
      await tester.pump();
      expect(find.byKey(const Key('exercise.check.button')), findsNothing);
    });

    testWidgets('the next exercise starts unpaired and checks its own pairs', (
      tester,
    ) async {
      final first = build(vocare, _bundle);
      final next = build(vocare, 'ind.perf.akt');
      final responses = await pump(tester, first);
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      await tester.pumpWidget(
        wrapInApp(
          ExerciseMatchWidget(
            word: vocare,
            exercise: next,
            onResponse: responses.add,
          ),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise.check.button')), findsNothing);
      expect(find.textContaining(' · '), findsNothing);
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      expect(find.text('Richtig'), findsOneWidget);
      await tapNext(tester);
      expect(attribute(vocare, next, responses.single), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    for (final language in ['de', 'en']) {
      testWidgets('shows $language text and no key', (tester) async {
        await pump(tester, build(vocare, _bundle), language: language);
        final keys = translationKeys(language);
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '');
        expect(texts, isNotEmpty);
        expect(texts.where(keys.contains), isEmpty);
      });
    }
  });

  test('de and en have the same exercise.match keys', () {
    Set<String> matchKeys(String l) => translationKeys(
      l,
    ).where((k) => k.startsWith('exercise.match.')).toSet();
    expect(matchKeys('de'), isNotEmpty);
    expect(matchKeys('de'), matchKeys('en'));
  });
}
