import 'dart:math';

import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

/// An [ExerciseContext] whose German texts come from [FakeGermanForms].
ExerciseContext fakeExerciseContext({
  Set<GrammarBundle> unlocked = const {},
  List<PracticeItem> pool = const [],
}) => ExerciseContext(
  unlocked: unlocked,
  pool: pool,
  german: const FakeGermanForms(),
);

/// Latin form → choose its German text among the other forms of the bundle.
/// Builds only for an unlocked bundle and a word of the pool.
class FakeLatDeGenerator implements ExerciseGenerator {
  const FakeLatDeGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.latDeWahl;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
    if (!ctx.pool.contains(word)) {
      throw CannotBuild('${word.id} is not in the pool');
    }
    final keys = [
      for (final key in word.formOrder)
        if (bundleOf(word, key) == bundle) key,
    ];
    if (keys.length < 2) {
      throw CannotBuild('${word.id} has fewer than 2 forms in $bundle');
    }
    final target = keys[rng.nextInt(keys.length)];
    final options = [
      for (final key in keys)
        FormOption(
          text: ctx.german.render(word, key),
          formKey: key,
          lexemeId: word.id,
        ),
    ];
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.latDeWahl.question',
      questionParams: {'form': word.forms[word.formOrder.indexOf(target)]},
      answer: ChoiceAnswer(
        options,
        options.singleWhere((o) => o.formKey == target),
      ),
    );
  }
}
