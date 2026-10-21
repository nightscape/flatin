import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_bestimmen.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/exercise_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;
  setUpAll(() async {
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
  });

  ExerciseContext ctx(PracticeItem word, GrammarBundle bundle) =>
      fakeExerciseContext(unlocked: {bundle}, pool: nouns);

  Exercise build(PracticeItem word, int seed) {
    final bundle = bundleOf(word, word.formOrder.first);
    return const BestimmenGenerator().build(
      word,
      bundle,
      ctx(word, bundle),
      Random(seed),
    );
  }

  String label(PracticeItem w, FormKey k) =>
      w.formLabels[w.formOrder.indexOf(k)].displayName;

  Set<FormKey> readings(PracticeItem w, String shown) => {
    for (var i = 0; i < w.formOrder.length; i++)
      if (w.acceptedForms[i].map(norm).contains(norm(shown))) w.formOrder[i],
  };

  test('the right option names every reading of the shown spelling', () {
    var ambiguous = 0;
    for (final word in nouns) {
      for (var seed = 0; seed < 5; seed++) {
        final e = build(word, seed);
        final answer = e.answer as ChoiceAnswer;
        final shown = e.questionParams['form']!;
        final keys = readings(word, shown);
        if (keys.length > 1) ambiguous++;
        for (final key in keys) {
          for (final part in label(word, key).split(RegExp('[ /:,]+'))) {
            expect(answer.right.text, contains(part));
          }
        }
        expect(answer.options.length, 4);
        for (final o in answer.options) {
          if (!identical(o, answer.right)) {
            expect(keys, isNot(contains(o.formKey)), reason: word.id);
            expect(readings(word, shown), isNot(contains(o.formKey)));
          }
        }
      }
    }
    expect(ambiguous, greaterThan(0));
  });

  test('a unique spelling names exactly one label', () {
    var unique = 0;
    for (final word in nouns) {
      final e = build(word, 0);
      final shown = e.questionParams['form']!;
      if (readings(word, shown).length != 1) continue;
      unique++;
      final key = readings(word, shown).single;
      expect(
        (e.answer as ChoiceAnswer).right.text,
        label(word, key),
        reason: word.id,
      );
    }
    expect(unique, greaterThan(0));
  });

  test('one seed builds one exercise', () {
    for (final word in nouns.take(10)) {
      final a = build(word, 7).answer as ChoiceAnswer;
      final b = build(word, 7).answer as ChoiceAnswer;
      expect(a.options.map((o) => o.text), b.options.map((o) => o.text));
    }
  });

  test('a wrong label blames the grammar, the right one is good', () {
    final word = nouns.first;
    final e = build(word, 0);
    final answer = e.answer as ChoiceAnswer;
    expect(attribute(word, e, ChosenOption(answer.right)), (
      word: Rating.good,
      grammar: Rating.good,
    ));
    final wrong = answer.options.firstWhere((o) => o != answer.right);
    expect(attribute(word, e, ChosenOption(wrong)), (
      word: Rating.good,
      grammar: Rating.again,
    ));
  });

  test('a noun pair at stability 0 builds both odd-one-out and bestimmen', () {
    final word = nouns.firstWhere((n) => n.id == 'nouns:puella');
    final bundle = bundleOf(word, word.formOrder.first);
    final kinds = {
      for (var seed = 0; seed < 60; seed++)
        buildExercise(word, bundle, ctx(word, bundle), 0, Random(seed)).kind,
    };
    expect(
      kinds,
      containsAll([ExerciseKind.irrlaeufer, ExerciseKind.bestimmen]),
    );
  });

  test('the English UI builds bestimmen: it shows no German text', () {
    final word = nouns.first;
    final bundle = bundleOf(word, word.formOrder.first);
    final e = const BestimmenGenerator().build(
      word,
      bundle,
      ExerciseContext(unlocked: {bundle}, pool: nouns, german: const NoForms()),
      Random(0),
    );
    expect(e.kind, ExerciseKind.bestimmen);
  });
}
