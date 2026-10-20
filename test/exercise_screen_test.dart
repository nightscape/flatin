import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _sizes = {'phone': Size(390, 800), 'wide': Size(1400, 800)};
final _keyShape = RegExp(r'^[a-z][A-Za-z]*(\.[A-Za-z]+)+$');
final _word = RegExp(r'[A-Za-zÄÖÜäöüß]+');

Future<Exercise> _choice() async {
  final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
  final built = const FakeLatDeGenerator(
    FakeGermanForms(),
  ).build(vocare, 'ind.fut2.pass', Random(1));
  return Exercise(
    wordCardId: built.wordCardId,
    grammarCardId: built.grammarCardId,
    kind: built.kind,
    questionKey: 'exercise.screen.sampleQuestion',
    questionParams: built.questionParams,
    answer: built.answer,
  );
}

Exercise _typed(Exercise choice) {
  final right = (choice.answer as ChoiceAnswer).right;
  final expected = FormOption(
    text: 'vocāre',
    formKey: right.formKey,
    lexemeId: right.lexemeId,
  );
  return Exercise(
    wordCardId: choice.wordCardId,
    grammarCardId: choice.grammarCardId,
    kind: ExerciseKind.formBilden,
    questionKey: choice.questionKey,
    questionParams: choice.questionParams,
    answer: TypedAnswer(expected, [expected.text]),
  );
}

Future<List<ExerciseResponse>> _pump(
  WidgetTester tester,
  Exercise exercise,
  String size, {
  String language = 'de',
}) async {
  tester.view.physicalSize = _sizes[size]!;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final responses = <ExerciseResponse>[];
  await tester.pumpWidget(
    wrapInApp(
      ExerciseScreen(exercise: exercise, onResponse: responses.add),
      forcedLocale: Locale(language),
    ),
  );
  await tester.pumpAndSettle();
  return responses;
}

Set<String> _words(String language) => {
  for (final m in _word.allMatches(
    jsonDecode(
      File('assets/flutter_i18n/$language.json').readAsStringSync(),
    ).toString(),
  ))
    m[0]!.toLowerCase(),
};

void main() {
  for (final size in _sizes.keys) {
    group('on a $size screen', () {
      testWidgets('picking the right option says right and reports it', (
        tester,
      ) async {
        final exercise = await _choice();
        final answer = exercise.answer as ChoiceAnswer;
        final responses = await _pump(tester, exercise, size);

        await tester.tap(
          find.byKey(
            Key('exercise.option.${answer.options.indexOf(answer.right)}'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Richtig'), findsOneWidget);
        expect(responses, isEmpty);
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        expect((responses.single as ChosenOption).chosen, same(answer.right));
      });

      testWidgets('a second press of next reports nothing more', (
        tester,
      ) async {
        final exercise = await _choice();
        final responses = await _pump(tester, exercise, size);
        await tester.tap(find.byKey(const Key('exercise.option.0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        expect(responses, hasLength(1));
      });

      testWidgets('picking a wrong option names the right text', (
        tester,
      ) async {
        final exercise = await _choice();
        final answer = exercise.answer as ChoiceAnswer;
        final responses = await _pump(tester, exercise, size);
        final wrong = answer.options.indexWhere(
          (o) => !identical(o, answer.right),
        );

        await tester.tap(find.byKey(Key('exercise.option.$wrong')));
        await tester.pumpAndSettle();

        expect(
          find.text('Falsch. Richtig ist: ${answer.right.text}'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(Key('exercise.option.$wrong')));
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        expect(responses, hasLength(1));
        expect(
          (responses.single as ChosenOption).chosen,
          answer.options[wrong],
        );
      });

      testWidgets('a typed form without macrons counts as right', (
        tester,
      ) async {
        final responses = await _pump(tester, _typed(await _choice()), size);

        await tester.enterText(
          find.byKey(const Key('exercise.input')),
          ' Vocare ',
        );
        await tester.tap(find.byKey(const Key('exercise.check.button')));
        await tester.pumpAndSettle();

        expect(find.text('Richtig'), findsOneWidget);
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        expect((responses.single as TypedText).text, ' Vocare ');
      });

      testWidgets('a wrong typed form names the expected spelling', (
        tester,
      ) async {
        await _pump(tester, _typed(await _choice()), size);

        await tester.enterText(
          find.byKey(const Key('exercise.input')),
          'vocere',
        );
        await tester.tap(find.byKey(const Key('exercise.check.button')));
        await tester.pumpAndSettle();

        expect(find.text('Falsch. Richtig ist: vocāre'), findsOneWidget);
      });

      for (final language in ['de', 'en']) {
        testWidgets('shows $language text and no key or other language', (
          tester,
        ) async {
          final choice = await _choice();
          final other = language == 'de' ? 'en' : 'de';
          final foreign = _words(other).difference(_words(language));
          final keys = translationKeys(language);
          for (final exercise in [choice, _typed(choice)]) {
            await _pump(tester, exercise, size, language: language);
            if (exercise.answer is TypedAnswer) {
              await tester.enterText(
                find.byKey(const Key('exercise.input')),
                'x',
              );
              await tester.tap(find.byKey(const Key('exercise.check.button')));
            } else {
              await tester.tap(find.byKey(const Key('exercise.option.0')));
            }
            await tester.pumpAndSettle();
            final texts = tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.data ?? '');
            expect(texts, isNotEmpty);
            for (final text in texts) {
              expect(keys.contains(text) || _keyShape.hasMatch(text), isFalse);
              expect(
                _word
                    .allMatches(text)
                    .where((m) => foreign.contains(m[0]!.toLowerCase())),
                isEmpty,
                reason: '$language screen shows "$text"',
              );
            }
          }
        });
      }
    });
  }
}
