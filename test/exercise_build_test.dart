import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_build.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _generator = BuildFormGenerator();
const _bundle = 'konj.impf.pass';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem audire;
  late PracticeItem dicere;
  late PracticeItem noun;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    audire = verbs.singleWhere((i) => i.id == 'verbs:audire');
    dicere = verbs.singleWhere((i) => i.id == 'verbs:dicere');
    noun = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
  });

  String bundleOfFirst(PracticeItem item) =>
      bundleOf(item, item.formOrder.first);

  TypedAnswer typed(Exercise e) => e.answer as TypedAnswer;

  group('D1: builds a typed exercise', () {
    test('for a verb, with the accepted variants and the prompt params', () {
      final bundle = bundleOf(audire, audire.formOrder.first);
      for (int seed = 0; seed < 10; seed++) {
        final e = _generator.build(
          audire,
          bundle,
          fakeExerciseContext(),
          Random(seed),
        );
        final answer = typed(e);
        final index = audire.formOrder.indexOf(answer.expected.formKey);
        expect(bundleOf(audire, answer.expected.formKey), bundle);
        expect(e.kind, ExerciseKind.formBilden);
        expect(e.wordCardId, audire.id);
        expect(e.grammarCardId, GrammarCardId('verbs', bundle));
        expect(e.questionKey, 'exercise.build.question');
        expect(e.questionParams['word'], audire.lemma);
        expect(e.questionParams['label'], isNotEmpty);
        expect(answer.expected.text, audire.forms[index]);
        expect(answer.expected.builtWrongBy, isNull);
        expect(answer.accepted, audire.acceptedForms[index]);
      }
    });

    test('a form with a variant spelling accepts all of them', () async {
      final vocare = (await loadPracticeItems(
        'lib/data/latin_verbs.yaml',
      )).singleWhere((i) => i.id == 'verbs:vocare');
      final withVariants = [
        for (int seed = 0; seed < 60; seed++)
          typed(
            _generator.build(
              vocare,
              'ind.perf.akt',
              fakeExerciseContext(),
              Random(seed),
            ),
          ),
      ].where((a) => a.accepted.length > 1);
      expect(withVariants, isNotEmpty);
      for (final a in withVariants) {
        expect(
          a.accepted,
          vocare.acceptedForms[vocare.formOrder.indexOf(a.expected.formKey)],
        );
      }
    });

    test('for a noun', () {
      final bundle = bundleOfFirst(noun);
      final e = _generator.build(
        noun,
        bundle,
        fakeExerciseContext(),
        Random(0),
      );
      expect(e.grammarCardId, GrammarCardId('nouns', bundle));
      expect(typed(e).accepted.first, typed(e).expected.text);
    });

    test('the app registers it for formBilden', () {
      expect(
        generatorFor(ExerciseKind.formBilden, exerciseGenerators),
        isA<BuildFormGenerator>(),
      );
    });
  });

  group('D1: cannot build', () {
    test('when the word has no form in the bundle', () {
      expect(
        () => _generator.build(
          audire,
          bundleOfFirst(noun),
          fakeExerciseContext(),
          Random(0),
        ),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('verbs:audire'),
          ),
        ),
      );
    });
  });

  group('D2: attribution of the typed answer', () {
    late Exercise exercise;
    late String bundle;
    setUp(() {
      bundle = bundleOf(dicere, dicere.formOrder.first);
      exercise = _generator.build(
        dicere,
        bundle,
        fakeExerciseContext(),
        Random(3),
      );
    });

    Attribution answer(String text) =>
        attribute(dicere, exercise, TypedText(text));

    test('the shown spelling is Good/Good', () {
      expect(answer(typed(exercise).expected.text), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('every accepted variant is Good/Good', () {
      for (final spelling in typed(exercise).accepted) {
        expect(answer(spelling), (word: Rating.good, grammar: Rating.good));
      }
    });

    test('gibberish is Again/Again', () {
      expect(answer('qqqq'), (word: Rating.again, grammar: Rating.again));
    });

    test('another form of the word blames the grammar card only', () {
      final key = typed(exercise).expected.formKey;
      final other = dicere.formOrder.firstWhere(
        (k) => !dicere.accepts(
          dicere.formOrder.indexOf(key),
          dicere.forms[dicere.formOrder.indexOf(k)],
        ),
      );
      expect(answer(dicere.forms[dicere.formOrder.indexOf(other)]), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });
  });

  group('D3: the generic screen shows and answers it', () {
    testWidgets('prompt, right answer, wrong answer', (tester) async {
      final e = _generator.build(
        audire,
        _bundle,
        fakeExerciseContext(),
        Random(1),
      );
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
      expect(prompt.data, '${e.questionParams['label']} von audīre');

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

  test('D4: both languages hold the build keys', () {
    for (final code in ['de', 'en']) {
      expect(translationKeys(code), contains('exercise.build.question'));
    }
  });
}
