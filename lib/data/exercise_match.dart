import 'dart:math';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';

/// Four Latin forms of one word, each to the German text that fits it alone.
/// Produced here for the selection; read by the matching widget and `attribute`.
class MatchGenerator implements ExerciseGenerator {
  const MatchGenerator();

  static const pairCount = 4;

  @override
  ExerciseKind get kind => ExerciseKind.zuordnen;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (!ctx.german.covers(word)) {
      throw CannotBuild('${word.id} has no German forms');
    }
    if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
    final keys = [
      for (final key in word.formOrder)
        if (bundleOf(word, key) == bundle) key,
    ]..shuffle(rng);

    final latinTaken = <String>{};
    final germanTaken = <String>{};
    final pairs = <(FormOption, FormOption)>[];
    for (final key in keys) {
      if (pairs.length == pairCount) break;
      final latin = word.forms[word.formOrder.indexOf(key)];
      final german = ctx.german.render(word, key);
      if (latinTaken.contains(norm(latin)) || germanTaken.contains(german)) {
        continue;
      }
      latinTaken.add(norm(latin));
      germanTaken.add(german);
      pairs.add((
        FormOption(text: latin, formKey: key, lexemeId: word.id),
        FormOption(text: german, formKey: key, lexemeId: word.id),
      ));
    }
    if (pairs.length < pairCount) {
      throw CannotBuild(
        '${word.id} has only ${pairs.length} distinguishable forms in $bundle',
      );
    }
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.match.question',
      questionParams: {'word': word.lemma},
      answer: MatchingAnswer(pairs),
    );
  }
}
