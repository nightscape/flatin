import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'in English, vocāre and appellāre never share a vocab exercise',
    () async {
      final vocab = await loadPracticeItems(
        'lib/data/latin_vocab.yaml',
        language: 'en',
      );
      final lemmaOf = {for (final w in vocab) w.id: w.lemma};
      final ctx = ExerciseContext(
        unlocked: {'Vokabel'},
        pool: vocab,
        german: const NoForms(),
      );
      const pair = {'aliquem aliquid vocāre', 'aliquem aliquid appellāre'};
      final shown = <String>{};
      for (final word in vocab) {
        for (final generator in exerciseGenerators) {
          if (!{
            ExerciseKind.latDeWahl,
            ExerciseKind.deLatWahl,
            ExerciseKind.zuordnen,
          }.contains(generator.kind)) {
            continue;
          }
          for (var seed = 0; seed < 20; seed++) {
            final answer = generator
                .build(word, 'Vokabel', ctx, Random(seed))
                .answer;
            final lemmas = switch (answer) {
              ChoiceAnswer(:final options) => {
                for (final o in options) lemmaOf[o.lexemeId]!,
              },
              MatchingAnswer(:final pairs) => {
                for (final (o, _) in pairs) lemmaOf[o.lexemeId]!,
              },
              _ => <String>{},
            };
            if (lemmas.containsAll(pair)) {
              shown.add('${generator.kind.name} ${word.lemma}');
            }
          }
        }
      }
      expect(shown, isEmpty, reason: shown.join('\n'));
    },
  );
}
