import 'dart:math';

import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

/// Latin form → choose its German text among the other forms of the bundle.
class FakeLatDeGenerator implements ExerciseGenerator {
  final GermanForms german;

  const FakeLatDeGenerator(this.german);

  @override
  ExerciseKind get kind => ExerciseKind.latDeWahl;

  @override
  Exercise build(PracticeItem word, GrammarBundle bundle, Random rng) {
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
          text: german.render(word, key),
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
