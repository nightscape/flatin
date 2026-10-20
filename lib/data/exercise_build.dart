/// Kind A6: the learner types one form that the prompt names by its features.
library;

import 'dart:math';

import '../models/exercise.dart';
import '../models/practice_item.dart';

/// Asks for one random form of the word's bundle.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// selection.
class BuildFormGenerator implements ExerciseGenerator {
  const BuildFormGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.formBilden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final indexes = [
      for (int i = 0; i < word.formOrder.length; i++)
        if (bundleOf(word, word.formOrder[i]) == bundle) i,
    ];
    if (indexes.isEmpty) {
      throw CannotBuild('${word.id} has no form in $bundle');
    }
    final index = indexes[rng.nextInt(indexes.length)];
    final key = word.formOrder[index];
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.build.question',
      questionParams: {
        'label': describeLabels([word.formLabels[index]]),
        'word': word.lemma,
      },
      answer: TypedAnswer(
        FormOption(text: word.forms[index], formKey: key, lexemeId: word.id),
        word.acceptedForms[index],
      ),
    );
  }
}
