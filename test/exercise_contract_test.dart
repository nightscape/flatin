import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/german_forms.dart';
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
        const FakeLatDeGenerator(FakeGermanForms()),
      ]);

      final exercise = generator.build(vocare, 'ind.fut2.pass', Random(1));

      expect(exercise.wordCardId, PracticeItemCard.generateItemId(vocare));
      expect(exercise.grammarCardId, 'grammar:verbs:ind.fut2.pass');
      final answer = exercise.answer as ChoiceAnswer;
      expect(answer.right.text, '${vocare.lemma}@${answer.right.formKey}');
      expect(
        () => generator.build(vocare, 'konj.fut.akt', Random(1)),
        throwsA(isA<CannotBuild>()),
      );
    },
  );

  test('attribute is still to be written', () async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    final exercise = const FakeLatDeGenerator(
      FakeGermanForms(),
    ).build(vocare, 'ind.fut2.pass', Random(1));
    final right = (exercise.answer as ChoiceAnswer).right;

    expect(
      () => attribute(vocare, exercise, ChosenOption(right)),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
