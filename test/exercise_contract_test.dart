import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';

import 'support/exercise_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a verb bundle is Modus.Tempus.Genus verbi, a noun bundle its type',
    () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
      expect(
        GrammarCardId.of(vocare, 'ind.fut2.pass.3.pl'),
        'grammar:verbs:ind.fut2.pass',
      );
      final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
      final noun = nouns.firstWhere((i) => i.type == 'U-Deklination');
      expect(
        GrammarCardId.of(noun, noun.formOrder.first),
        'grammar:nouns:U-Deklination',
      );
    },
  );

  test(
    'a generator from the registry builds an exercise with both card ids',
    () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
      final generator = generatorFor(ExerciseKind.latDeWahl, [
        const FakeLatDeGenerator(),
      ]);
      final ctx = fakeExerciseContext(
        unlocked: {'ind.fut2.pass', 'konj.fut.akt'},
        pool: [vocare],
      );

      final exercise = generator.build(vocare, 'ind.fut2.pass', ctx, Random(1));

      expect(exercise.wordCardId, PracticeItemCard.generateItemId(vocare));
      expect(exercise.grammarCardId, 'grammar:verbs:ind.fut2.pass');
      final answer = exercise.answer as ChoiceAnswer;
      expect(answer.right.text, '${vocare.lemma}@${answer.right.formKey}');
      expect(
        () => generator.build(vocare, 'konj.fut.akt', ctx, Random(1)),
        throwsA(isA<CannotBuild>()),
      );
    },
  );

  test(
    'a generator reads the unlocked bundles and the pool of its context',
    () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
      const generator = FakeLatDeGenerator();
      Exercise build(ExerciseContext ctx) =>
          generator.build(vocare, 'ind.fut2.pass', ctx, Random(1));

      expect(
        build(
          fakeExerciseContext(unlocked: {'ind.fut2.pass'}, pool: [vocare]),
        ).grammarCardId,
        'grammar:verbs:ind.fut2.pass',
      );
      expect(
        () => build(
          fakeExerciseContext(unlocked: {'ind.fut.pass'}, pool: [vocare]),
        ),
        throwsA(isA<CannotBuild>()),
      );
      expect(
        () => build(fakeExerciseContext(unlocked: {'ind.fut2.pass'}, pool: [])),
        throwsA(isA<CannotBuild>()),
      );
    },
  );
}
