/// Kind A9: a two-word form with one wrong word; the learner types the form.
library;

import 'dart:math';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';

/// Swaps the participle or the auxiliary of a compound form (`vocātī sunt`)
/// for the one of the same form in the other number (`vocātus sunt`,
/// `vocātī est`). The prompt names the form, so the right answer is unique.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// generic exercise screen and `attribute`.
class FindErrorGenerator implements ExerciseGenerator {
  const FindErrorGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.fehlerFinden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    assert(ctx.unlocked.contains(bundle), 'the bundle $bundle is not unlocked');
    final spellings = {
      for (final forms in word.acceptedForms) ...forms.map(norm),
    };
    final candidates = <(int, String)>[];
    for (int i = 0; i < word.formOrder.length; i++) {
      final key = word.formOrder[i];
      if (bundleOf(word, key) != bundle) continue;
      final partner = _otherNumber(word, i);
      final parts = word.forms[i].split(' ');
      if (partner == null || parts.length != 2) continue;
      final partnerParts = word.forms[partner].split(' ');
      if (partnerParts.length != 2) continue;
      for (final wrong in [
        '${partnerParts[0]} ${parts[1]}',
        '${parts[0]} ${partnerParts[1]}',
      ]) {
        if (!spellings.contains(norm(wrong))) candidates.add((i, wrong));
      }
    }
    if (candidates.isEmpty) {
      throw CannotBuild('${word.id} has no two-word form in $bundle to spoil');
    }
    final (index, wrong) = candidates[rng.nextInt(candidates.length)];
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.finderror.question',
      questionParams: {
        'label': describeLabels([word.formLabels[index]]),
        'word': word.lemma,
        'wrong': wrong,
      },
      answer: TypedAnswer(
        FormOption(
          text: word.forms[index],
          formKey: word.formOrder[index],
          lexemeId: word.id,
        ),
        word.acceptedForms[index],
      ),
    );
  }

  /// The index of the form that differs from form [index] only in `numerus`.
  int? _otherNumber(PracticeItem word, int index) {
    final features = word.formLabels[index].features;
    final number = features['numerus'];
    if (number == null) return null;
    final other = number == 'sg' ? 'pl' : 'sg';
    final found = [
      for (int j = 0; j < word.formOrder.length; j++)
        if (_sameBut(features, word.formLabels[j].features, other)) j,
    ];
    return found.isEmpty ? null : found.single;
  }

  bool _sameBut(
    Map<String, String> asked,
    Map<String, String> candidate,
    String otherNumber,
  ) =>
      candidate.length == asked.length &&
      asked.entries.every(
        (e) => candidate[e.key] == (e.key == 'numerus' ? otherNumber : e.value),
      );
}
