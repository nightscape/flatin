import 'dart:math';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';

/// One Latin form; the learner picks its grammatical label among the labels of
/// other forms of the word. Every reading of the shown spelling is named in
/// the right option.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// generic exercise screen and `attribute`.
class BestimmenGenerator implements ExerciseGenerator {
  static const _optionCount = 4;

  const BestimmenGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.bestimmen;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    assert(ctx.unlocked.contains(bundle), 'the bundle $bundle is not unlocked');
    final keys = [
      for (final key in word.formOrder)
        if (bundleOf(word, key) == bundle) key,
    ];
    final target = keys[rng.nextInt(keys.length)];
    Set<String> spellings(FormKey key) =>
        word.acceptedForms[word.formOrder.indexOf(key)].map(norm).toSet();
    final shown = spellings(target);
    final readings = [
      for (final key in keys)
        if (spellings(key).any(shown.contains)) key,
    ];
    final others = [
      for (final key in keys)
        if (!readings.contains(key)) key,
    ]..shuffle(rng);
    if (others.length < _optionCount - 1) {
      throw CannotBuild(
        '${word.id} has fewer than ${_optionCount - 1} forms in $bundle '
        'that differ in spelling from ${word.forms[word.formOrder.indexOf(target)]}',
      );
    }
    FormLabel label(FormKey key) =>
        word.formLabels[word.formOrder.indexOf(key)];
    final right = FormOption(
      text: describeLabels([for (final key in readings) label(key)]),
      formKey: target,
      lexemeId: word.id,
    );
    final options = [
      right,
      for (final key in others.take(_optionCount - 1))
        FormOption(
          text: label(key).displayName,
          formKey: key,
          lexemeId: word.id,
        ),
    ]..shuffle(rng);
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.bestimmen.question',
      questionParams: {
        'form': word.forms[word.formOrder.indexOf(target)],
        'word': word.lemma,
      },
      answer: ChoiceAnswer(options, right),
    );
  }
}
