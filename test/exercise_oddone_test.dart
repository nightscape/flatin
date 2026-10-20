import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_oddone.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/exercise_fakes.dart';
import 'support/hand_items.dart';
import 'support/word_classification_harness.dart';

const _bundle = 'ind.praes.akt';

Set<GrammarBundle> _bundles(PracticeItem item) => {
  for (final key in item.formOrder) bundleOf(item, key),
};

Map<String, String> _features(PracticeItem item, FormKey key) =>
    item.formLabels[item.formOrder.indexOf(key)].features;

/// Whether [lone] is the only option whose value on [axis] differs.
bool _loneOn(PracticeItem item, List<FormOption> options, FormOption lone) {
  final axes = options.expand((o) => _features(item, o.formKey).keys).toSet();
  return axes.any((axis) {
    final others = options
        .where((o) => o != lone)
        .map((o) => _features(item, o.formKey)[axis])
        .toSet();
    return others.length == 1 &&
        others.single != _features(item, lone.formKey)[axis];
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
  });

  Exercise build(
    PracticeItem item,
    GrammarBundle bundle,
    int seed, {
    Set<GrammarBundle>? unlocked,
  }) => const OddOneOutGenerator().build(
    item,
    bundle,
    fakeExerciseContext(unlocked: unlocked ?? _bundles(item)),
    Random(seed),
  );

  group('D1 builds', () {
    test('four forms of the word, one of them the lone one', () {
      for (int seed = 0; seed < 30; seed++) {
        final exercise = build(vocare, _bundle, seed);
        final answer = exercise.answer as ChoiceAnswer;
        expect(exercise.kind, ExerciseKind.irrlaeufer);
        expect(exercise.wordCardId, 'verbs:vocare');
        expect(exercise.grammarCardId, 'grammar:verbs:$_bundle');
        expect(exercise.questionKey, 'exercise.oddone.question');
        expect(answer.options, hasLength(4));
        expect(answer.options.map((o) => o.lexemeId).toSet(), {'verbs:vocare'});
        expect(_loneOn(vocare, answer.options, answer.right), isTrue);
        for (final wrong in answer.options.where((o) => o != answer.right)) {
          expect(_loneOn(vocare, answer.options, wrong), isFalse);
        }
        for (final o in answer.options) {
          expect(o.text, vocare.forms[vocare.formOrder.indexOf(o.formKey)]);
        }
      }
    });

    test('the three others lie in the asked bundle', () {
      for (int seed = 0; seed < 30; seed++) {
        final answer = build(vocare, _bundle, seed).answer as ChoiceAnswer;
        final inBundle = answer.options
            .where((o) => bundleOf(vocare, o.formKey) == _bundle)
            .length;
        expect(inBundle, anyOf(3, 4));
      }
    });

    test('the odd form comes only from an unlocked bundle', () {
      for (int seed = 0; seed < 30; seed++) {
        final answer =
            build(vocare, _bundle, seed, unlocked: {_bundle}).answer
                as ChoiceAnswer;
        for (final o in answer.options) {
          expect(bundleOf(vocare, o.formKey), _bundle);
        }
      }
    });

    test('with the neighbour bundles unlocked, the odd form can leave', () {
      final left = {
        for (int seed = 0; seed < 60; seed++)
          bundleOf(
            vocare,
            (build(vocare, _bundle, seed).answer as ChoiceAnswer).right.formKey,
          ),
      };
      expect(left.length, greaterThan(1));
    });
  });

  group('D1 cannot build', () {
    test('a bundle with fewer than three forms', () {
      expect(
        () => build(vocare, 'inf.praes.akt', 0),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('fewer than 3 forms'),
          ),
        ),
      );
    });

    test('majority forms that read the same leave no unambiguous odd form', () {
      final item = handItem(
        dataFileId: 'verbs',
        lemma: 'vocare',
        axes: fullVerbAxes,
        forms: {
          'ind.praes.akt.1.sg': ['voco'],
          'ind.praes.akt.2.sg': ['voco'],
          'ind.praes.akt.3.sg': ['voco'],
          'ind.praes.akt.1.pl': ['vocamus'],
        },
      );
      expect(
        () => build(item, bundleOf(item, item.formOrder.first), 0),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('no unambiguous odd form'),
          ),
        ),
      );
    });

    test('an odd form that reads like a majority form is not offered', () {
      final item = handItem(
        dataFileId: 'verbs',
        lemma: 'vocare',
        axes: fullVerbAxes,
        forms: {
          'ind.praes.akt.1.sg': ['a'],
          'ind.praes.akt.2.sg': ['b'],
          'ind.praes.akt.3.sg': ['c'],
          'ind.praes.akt.1.pl': ['a', 'x'],
        },
      );
      expect(
        () => build(item, bundleOf(item, item.formOrder.first), 0),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('an odd form two features away is not a neighbour', () {
      final item = handItem(
        dataFileId: 'verbs',
        lemma: 'vocare',
        axes: fullVerbAxes,
        forms: {
          'ind.praes.akt.1.sg': ['a'],
          'ind.praes.akt.2.sg': ['b'],
          'ind.praes.akt.3.sg': ['c'],
          'ind.fut.akt.1.pl': ['d'],
        },
      );
      expect(
        () => build(item, bundleOf(item, item.formOrder.first), 0),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('a second lone form on another feature makes the quartet unfit', () {
      final item = handItem(
        dataFileId: 'verbs',
        lemma: 'vocare',
        axes: fullVerbAxes,
        forms: {
          'ind.praes.akt.1.sg': ['a'],
          'ind.praes.akt.2.sg': ['b'],
          'ind.praes.akt.2.pl': ['c'],
          'ind.fut.akt.1.sg': ['d'],
        },
      );
      expect(
        () => build(item, bundleOf(item, item.formOrder.first), 0),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('D2 attribution', () {
    late Exercise exercise;
    late ChoiceAnswer answer;
    setUp(() {
      exercise = build(vocare, _bundle, 3);
      answer = exercise.answer as ChoiceAnswer;
    });

    test('the odd form: Good/Good', () {
      expect(attribute(vocare, exercise, ChosenOption(answer.right)), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('a form that shares the feature: word Good, grammar Again', () {
      for (final wrong in answer.options.where((o) => o != answer.right)) {
        expect(attribute(vocare, exercise, ChosenOption(wrong)), (
          word: Rating.good,
          grammar: Rating.again,
        ));
      }
    });

    test('a typed answer does not fit a choice', () {
      expect(
        () => attribute(vocare, exercise, const TypedText('voco')),
        throwsArgumentError,
      );
    });
  });

  group('D3 screen', () {
    Future<List<ExerciseResponse>> pump(
      WidgetTester tester,
      Exercise exercise,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final responses = <ExerciseResponse>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: exercise, onResponse: responses.add),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      return responses;
    }

    testWidgets('picking the odd form says right and reports it', (
      tester,
    ) async {
      final exercise = build(vocare, _bundle, 5);
      final answer = exercise.answer as ChoiceAnswer;
      final responses = await pump(tester, exercise);
      expect(
        find.text('Welche Form gehört nicht zu den anderen?'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          Key('exercise.option.${answer.options.indexOf(answer.right)}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Richtig'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.next.button')));
      expect((responses.single as ChosenOption).chosen, same(answer.right));
    });

    testWidgets('picking another form names the odd one', (tester) async {
      final exercise = build(vocare, _bundle, 5);
      final answer = exercise.answer as ChoiceAnswer;
      await pump(tester, exercise);
      final wrong = answer.options.indexWhere((o) => o != answer.right);
      await tester.tap(find.byKey(Key('exercise.option.$wrong')));
      await tester.pumpAndSettle();
      expect(
        find.text('Falsch. Richtig ist: ${answer.right.text}'),
        findsOneWidget,
      );
    });
  });
}
