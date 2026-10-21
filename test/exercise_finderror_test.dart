import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_finderror.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _generator = FindErrorGenerator();
const _bundle = 'ind.perf.pass';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem noun;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    noun = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
  });

  Exercise build(PracticeItem item, GrammarBundle bundle, int seed) =>
      _generator.build(
        item,
        bundle,
        fakeExerciseContext(unlocked: {bundle}),
        Random(seed),
      );

  TypedAnswer typed(Exercise e) => e.answer as TypedAnswer;

  group('D1: builds', () {
    test('a wrong two-word form that is no form of the word', () {
      final allForms = {
        for (final forms in vocare.acceptedForms) ...forms.map(norm),
      };
      for (int seed = 0; seed < 40; seed++) {
        final e = build(vocare, _bundle, seed);
        final wrong = e.questionParams['wrong']!;
        final right = typed(e).expected;
        final rightParts = right.text.split(' ');
        final wrongParts = wrong.split(' ');
        expect(allForms, isNot(contains(norm(wrong))));
        expect(
          [
            for (int i = 0; i < 2; i++) rightParts[i] != wrongParts[i],
          ].where((differs) => differs),
          hasLength(1),
        );
        expect(e.kind, ExerciseKind.fehlerFinden);
        expect(e.wordCardId, vocare.id);
        expect(e.grammarCardId, GrammarCardId('verbs', _bundle));
        expect(e.questionKey, 'exercise.finderror.question');
        expect(e.questionParams['word'], vocare.lemma);
        expect(e.questionParams['label'], isNotEmpty);
        expect(bundleOf(vocare, right.formKey), _bundle);
        expect(right.builtWrongBy, isNull);
        expect(
          typed(e).accepted,
          vocare.acceptedForms[vocare.formOrder.indexOf(right.formKey)],
        );
      }
    });

    test('both the participle and the auxiliary get spoiled', () {
      final spoiled = {
        for (int seed = 0; seed < 60; seed++)
          () {
            final e = build(vocare, _bundle, seed);
            return typed(e).expected.text.split(' ').first ==
                e.questionParams['wrong']!.split(' ').first;
          }(),
      };
      expect(spoiled, {true, false});
    });

    test('the app registers it for fehlerFinden', () {
      expect(
        generatorFor(ExerciseKind.fehlerFinden, exerciseGenerators),
        isA<FindErrorGenerator>(),
      );
    });
  });

  group('D1: a swapped form that is a valid form', () {
    final allValid = syntheticVerb({
      'ind.fut.pass.sg': ['amātus est', 'amātī est'],
      'ind.fut.pass.pl': ['amātī sunt', 'amātus sunt'],
    });
    final oneValid = syntheticVerb({
      'ind.fut.pass.sg': ['amātus est', 'amātī est'],
      'ind.fut.pass.pl': ['amātī sunt'],
    });
    const bundle = 'ind.fut.pass';

    test('is never offered as the wrong form', () {
      for (int seed = 0; seed < 30; seed++) {
        expect(
          build(oneValid, bundle, seed).questionParams['wrong'],
          'amātus sunt',
        );
      }
    });

    test('leaves nothing to spoil when every swap is a valid form', () {
      expect(() => build(allValid, bundle, 0), throwsA(isA<CannotBuild>()));
    });
  });

  group('D1: cannot build', () {
    test('when the bundle has no two-word form', () {
      expect(
        () => build(vocare, 'ind.praes.akt', 0),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('verbs:vocare'),
          ),
        ),
      );
    });

    test('for a noun', () {
      expect(
        () => build(noun, bundleOf(noun, noun.formOrder.first), 0),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('D2: attribution of the typed answer', () {
    late Exercise exercise;
    setUp(() => exercise = build(vocare, _bundle, 3));

    Attribution answer(String text) =>
        attribute(vocare, exercise, TypedText(text));

    test('the right form is Good/Good', () {
      expect(answer(typed(exercise).expected.text), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('the shown wrong form is Again/Again', () {
      expect(answer(exercise.questionParams['wrong']!), (
        word: Rating.again,
        grammar: Rating.again,
      ));
    });

    test('another valid form blames the grammar card only', () {
      final key = typed(exercise).expected.formKey;
      final other =
          vocare.forms[vocare.formOrder.indexWhere(
            (k) => k != key && bundleOf(vocare, k) == _bundle,
          )];
      expect(answer(other), (word: Rating.good, grammar: Rating.again));
    });
  });

  group('D3: the generic screen shows and answers it', () {
    testWidgets('prompt, right answer', (tester) async {
      final e = build(vocare, _bundle, 1);
      final responses = <ExerciseResponse>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: e, onResponse: responses.add),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();

      final prompt = tester.widget<Text>(
        find.byKey(const Key('exercise.question')),
      );
      expect(
        prompt.data,
        contains('„${e.questionParams['wrong']}“ ist falsch'),
      );

      await tester.enterText(
        find.byKey(const Key('exercise.input')),
        typed(e).expected.text,
      );
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      expect(find.text('Richtig'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.next.button')));
      expect((responses.single as TypedText).text, typed(e).expected.text);
    });
  });

  test('D4: both languages hold the finderror keys', () {
    for (final code in ['de', 'en']) {
      expect(translationKeys(code), contains('exercise.finderror.question'));
    }
  });
}
