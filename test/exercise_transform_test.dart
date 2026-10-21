import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_transform.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _transform = TransformGenerator();
const _chain = FormChainGenerator();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem audire;
  late PracticeItem noun;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    audire = verbs.singleWhere((i) => i.id == 'verbs:audire');
    noun = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
  });

  Set<GrammarBundle> allBundles(PracticeItem item) => {
    for (final key in item.formOrder) bundleOf(item, key),
  };

  ExerciseContext ctx(PracticeItem item, [Set<GrammarBundle>? unlocked]) =>
      fakeExerciseContext(unlocked: unlocked ?? allBundles(item));

  TypedAnswer typed(Exercise e) => e.answer as TypedAnswer;

  String spelling(PracticeItem item, FormKey key) =>
      item.forms[item.formOrder.indexOf(key)];

  Map<String, String> features(PracticeItem item, FormKey key) =>
      item.formLabels[item.formOrder.indexOf(key)].features;

  group('D1: changeAxis', () {
    test('changes the voice and nothing else', () {
      final from = audire.formOrder.firstWhere(
        (k) => features(audire, k)['genus_verbi'] == 'akt',
      );
      final to = changeAxis(
        audire,
        from,
        'genus_verbi',
        allBundles(audire),
      ).toList();
      expect(to, isNotEmpty);
      for (final key in to) {
        final expected = {...features(audire, from), 'genus_verbi': 'pass'};
        expect(features(audire, key), expected);
      }
    });

    test('never offers a form that is spelled like the start', () async {
      final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
      var checked = 0;
      for (final item in nouns) {
        for (final key in item.formOrder) {
          for (final to in changeAxis(item, key, 'numerus', allBundles(item))) {
            checked++;
            expect(norm(spelling(item, to)), isNot(norm(spelling(item, key))));
          }
        }
      }
      expect(checked, greaterThan(100));
    });

    test('skips a bundle that is locked', () {
      final from = audire.formOrder.firstWhere(
        (k) => features(audire, k)['genus_verbi'] == 'akt',
      );
      expect(
        changeAxis(audire, from, 'genus_verbi', {bundleOf(audire, from)}),
        isEmpty,
      );
    });
  });

  group('D1: builds a transform', () {
    test('for a verb: the target is the start with one axis changed', () {
      final bundle = 'ind.praes.pass';
      for (int seed = 0; seed < 20; seed++) {
        final e = _transform.build(audire, bundle, ctx(audire), Random(seed));
        final answer = typed(e);
        final index = audire.formOrder.indexOf(answer.expected.formKey);
        expect(e.kind, ExerciseKind.umformen);
        expect(e.wordCardId, audire.id);
        expect(e.grammarCardId, GrammarCardId('verbs', bundle));
        expect(e.questionKey, 'exercise.transform.question');
        expect(bundleOf(audire, answer.expected.formKey), bundle);
        expect(answer.expected.text, audire.forms[index]);
        expect(answer.expected.builtWrongBy, isNull);
        expect(answer.accepted, audire.acceptedForms[index]);
        final target = features(audire, answer.expected.formKey);
        expect(
          audire.formOrder.any((k) {
            final f = features(audire, k);
            return spelling(audire, k) == e.questionParams['start'] &&
                {
                      ...f.keys,
                      ...target.keys,
                    }.where((a) => f[a] != target[a]).length ==
                    1;
          }),
          isTrue,
        );
        expect(e.questionParams['word'], audire.lemma);
        expect(e.questionParams['changes'], isNotEmpty);
      }
    });

    test('for a noun: the number changes', () {
      final bundle = bundleOf(noun, noun.formOrder.first);
      final e = _transform.build(noun, bundle, ctx(noun), Random(0));
      expect(e.grammarCardId, GrammarCardId('nouns', bundle));
      final start = noun.formOrder.firstWhere(
        (k) => spelling(noun, k) == e.questionParams['start'],
      );
      expect(
        features(noun, start)['numerus'],
        isNot(features(noun, typed(e).expected.formKey)['numerus']),
      );
    });

    test('the app registers it for umformen', () {
      expect(
        generatorFor(ExerciseKind.umformen, exerciseGenerators),
        isA<TransformGenerator>(),
      );
    });
  });

  group('D1: builds a chain', () {
    test('for a verb: 2 or 3 steps, joined in the prompt', () {
      final lengths = <int>{};
      for (int seed = 0; seed < 30; seed++) {
        final e = _chain.build(
          audire,
          'ind.praes.pass',
          ctx(audire),
          Random(seed),
        );
        final steps = e.questionParams['changes']!.split(' → ');
        lengths.add(steps.length);
        expect(steps.toSet().length, steps.length);
        expect(e.kind, ExerciseKind.formenKette);
        expect(e.questionKey, 'exercise.transform.chainQuestion');
        expect(bundleOf(audire, typed(e).expected.formKey), 'ind.praes.pass');
        expect(e.questionParams['start'], isNot(typed(e).expected.text));
      }
      expect(lengths, {2, 3});
    });

    test('the app registers it for formenKette', () {
      expect(
        generatorFor(ExerciseKind.formenKette, exerciseGenerators),
        isA<FormChainGenerator>(),
      );
    });
  });

  group('D5: the chain pins start, steps, filter and variants', () {
    final cube = syntheticVerb({
      for (final tempus in ['praes', 'fut'])
        for (final genus in ['akt', 'pass'])
          for (final numerus in ['sg', 'pl'])
            'ind.$tempus.$genus.$numerus': [
              '$tempus$genus$numerus',
              '$tempus$genus$numerus-v',
            ],
    });
    const changeable = ['tempus', 'genus_verbi', 'numerus'];

    Iterable<List<String>> orders(List<String> axes) sync* {
      if (axes.length <= 1) {
        yield axes;
        return;
      }
      for (final axis in axes) {
        for (final rest in orders([...axes]..remove(axis))) {
          yield [axis, ...rest];
        }
      }
    }

    test('shows the first spelling of the start and one label per step', () {
      final axes = cube.formLabels.first.axes;
      for (int seed = 0; seed < 40; seed++) {
        final e = _chain.build(cube, 'ind.praes.akt', ctx(cube), Random(seed));
        final start = cube.formOrder.singleWhere(
          (k) => spelling(cube, k) == e.questionParams['start'],
        );
        final target = features(cube, typed(e).expected.formKey);
        final differing = [
          for (final axis in changeable)
            if (features(cube, start)[axis] != target[axis]) axis,
        ];
        final readings = {
          for (final order in orders(differing))
            () {
              final reached = {...features(cube, start)};
              return order
                  .map((axis) {
                    reached[axis] = target[axis]!;
                    return axes.displayOf(axis, reached);
                  })
                  .join(' → ');
            }(),
        };
        expect(readings, contains(e.questionParams['changes']));
        expect(
          e.questionParams['changes']!.split(' → '),
          hasLength(differing.length),
        );
      }
    });

    test('the typed answer accepts every variant of the target', () {
      final e = _chain.build(cube, 'ind.praes.akt', ctx(cube), Random(0));
      final index = cube.formOrder.indexOf(typed(e).expected.formKey);
      expect(typed(e).accepted, hasLength(2));
      expect(typed(e).accepted, cube.acceptedForms[index]);
    });

    test('a start that is spelled like the target cannot be built', () {
      final square = syntheticVerb({
        'ind.akt.sg': ['a'],
        'ind.akt.pl': ['b'],
        'ind.pass.sg': ['b'],
        'ind.pass.pl': ['a'],
      });
      for (int seed = 0; seed < 20; seed++) {
        expect(
          () => _chain.build(square, 'ind.akt', ctx(square), Random(seed)),
          throwsA(isA<CannotBuild>()),
        );
      }
    });
  });

  group('D1: cannot build', () {
    for (final (name, generator) in [
      ('transform', _transform),
      ('chain', _chain),
    ]) {
      test('$name: the bundle is locked', () {
        expect(
          () => generator.build(
            audire,
            'ind.praes.pass',
            ctx(audire, {}),
            Random(0),
          ),
          throwsA(
            isA<CannotBuild>().having(
              (e) => e.reason,
              'reason',
              contains('locked'),
            ),
          ),
        );
      });

      test('$name: the word has no form in the bundle', () {
        expect(
          () => generator.build(
            audire,
            bundleOf(noun, noun.formOrder.first),
            ctx(audire, {bundleOf(noun, noun.formOrder.first)}),
            Random(0),
          ),
          throwsA(
            isA<CannotBuild>().having(
              (e) => e.reason,
              'reason',
              contains('no form'),
            ),
          ),
        );
      });

      test('$name: no neighbour of the form is unlocked', () {
        expect(
          () => generator.build(
            audire,
            'inf.praes.akt',
            ctx(audire, {'inf.praes.akt'}),
            Random(0),
          ),
          throwsA(isA<CannotBuild>()),
        );
      });
    }
  });

  group('D2: attribution of the typed answer', () {
    for (final (name, generator) in [
      ('transform', _transform),
      ('chain', _chain),
    ]) {
      late Exercise exercise;
      setUp(() {
        exercise = generator.build(
          audire,
          'ind.praes.pass',
          ctx(audire),
          Random(2),
        );
      });
      Attribution answer(String text) =>
          attribute(audire, exercise, TypedText(text));

      test('$name: the target and its variants are Good/Good', () {
        for (final text in typed(exercise).accepted) {
          expect(answer(text), (word: Rating.good, grammar: Rating.good));
        }
      });

      test('$name: the start form blames the grammar card only', () {
        expect(answer(exercise.questionParams['start']!), (
          word: Rating.good,
          grammar: Rating.again,
        ));
      });

      test('$name: gibberish is Again/Again', () {
        expect(answer('qqqq'), (word: Rating.again, grammar: Rating.again));
      });
    }
  });

  group('D3: the generic screen shows and answers it', () {
    for (final (name, generator, key) in [
      ('transform', _transform, 'exercise.transform.question'),
      ('chain', _chain, 'exercise.transform.chainQuestion'),
    ]) {
      testWidgets(name, (tester) async {
        final e = generator.build(
          audire,
          'ind.praes.pass',
          ctx(audire),
          Random(1),
        );
        final responses = <ExerciseResponse>[];
        await tester.pumpWidget(
          wrapInApp(
            ExerciseScreen(
              word: audire,
              exercise: e,
              onResponse: responses.add,
            ),
            forcedLocale: const Locale('de'),
          ),
        );
        await tester.pumpAndSettle();
        final prompt = tester.widget<Text>(
          find.byKey(const Key('exercise.question')),
        );
        expect(prompt.data, contains(e.questionParams['changes']!));
        expect(prompt.data, contains(e.questionParams['start']!));
        await tester.enterText(
          find.byKey(const Key('exercise.input')),
          typed(e).expected.text,
        );
        await tester.tap(find.byKey(const Key('exercise.check.button')));
        await tester.pumpAndSettle();
        expect(find.text('Richtig'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('exercise.next.button')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('exercise.next.button')));
        expect((responses.single as TypedText).text, typed(e).expected.text);
        expect(key, e.questionKey);
      });
    }
  });

  test('D4: both languages hold the transform keys', () {
    for (final code in ['de', 'en']) {
      expect(
        translationKeys(code),
        containsAll([
          'exercise.transform.question',
          'exercise.transform.chainQuestion',
        ]),
      );
    }
  });

  group('feedback labels', () {
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

    testWidgets('umformen: a wrong answer shows the target and the diagnosis', (
      tester,
    ) async {
      final e = _transform.build(
        audire,
        'ind.praes.pass',
        ctx(audire),
        Random(1),
      );
      final expected = (e.answer as TypedAnswer).expected;
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(word: audire, exercise: e, onResponse: (_) {}),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('exercise.input')), 'qqqq');
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      await seenLine(
        tester,
        '${expected.text} – ${labelOf(audire, expected.formKey)} (richtig)',
      );
      await seenLine(
        tester,
        'Du hast qqqq geschrieben – das passt zu keiner bekannten Form',
      );
    });

    testWidgets(
      'formenKette: a wrong answer shows the target and the diagnosis',
      (tester) async {
        final e = _chain.build(
          audire,
          'ind.praes.pass',
          ctx(audire),
          Random(1),
        );
        final expected = (e.answer as TypedAnswer).expected;
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          wrapInApp(
            ExerciseScreen(word: audire, exercise: e, onResponse: (_) {}),
            forcedLocale: const Locale('de'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('exercise.input')), 'qqqq');
        await tester.tap(find.byKey(const Key('exercise.check.button')));
        await tester.pumpAndSettle();
        await seenLine(
          tester,
          '${expected.text} – ${labelOf(audire, expected.formKey)} (richtig)',
        );
        await seenLine(
          tester,
          'Du hast qqqq geschrieben – das passt zu keiner bekannten Form',
        );
      },
    );
  });
}
