/// Kinds A8 and A10: the learner changes one axis of a given form, or
/// several axes one after the other, and types the form that results.
library;

import 'dart:math';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';

/// The axes a learner may be asked to change.
const _changeableAxes = ['genus_verbi', 'tempus', 'numerus'];

typedef _Step = ({FormKey from, FormKey to, String axis});

/// The keys of [item] that differ from [from] in [axis] only, whose bundle is
/// unlocked and whose spelling differs from the one of [from].
/// Produced here; read by both generators.
Iterable<FormKey> changeAxis(
  PracticeItem item,
  FormKey from,
  String axis,
  Set<GrammarBundle> unlocked,
) sync* {
  final fromIndex = item.formOrder.indexOf(from);
  final fromFeatures = item.formLabels[fromIndex].features;
  if (!fromFeatures.containsKey(axis)) return;
  for (int j = 0; j < item.formOrder.length; j++) {
    final features = item.formLabels[j].features;
    final sameElsewhere = {
      ...fromFeatures.keys,
      ...features.keys,
    }.where((a) => a != axis).every((a) => fromFeatures[a] == features[a]);
    if (sameElsewhere &&
        features[axis] != null &&
        features[axis] != fromFeatures[axis] &&
        unlocked.contains(bundleOf(item, item.formOrder[j])) &&
        norm(item.forms[j]) != norm(item.forms[fromIndex])) {
      yield item.formOrder[j];
    }
  }
}

/// Every way to reach [target] from a form [steps] axis changes away, each
/// axis used once.
Iterable<List<_Step>> _chains(
  PracticeItem item,
  FormKey target,
  int steps,
  Set<GrammarBundle> unlocked,
  Random rng, [
  Set<String> used = const {},
]) sync* {
  if (steps == 0) {
    yield [];
    return;
  }
  for (final axis in [..._changeableAxes]..shuffle(rng)) {
    if (used.contains(axis)) continue;
    for (final from in changeAxis(
      item,
      target,
      axis,
      unlocked,
    ).toList()..shuffle(rng)) {
      for (final rest in _chains(item, from, steps - 1, unlocked, rng, {
        ...used,
        axis,
      })) {
        yield [...rest, (from: from, to: target, axis: axis)];
      }
    }
  }
}

Exercise _build({
  required ExerciseKind kind,
  required String questionKey,
  required PracticeItem word,
  required GrammarBundle bundle,
  required List<_Step> steps,
}) {
  final axes = word.formLabels.first.axes;
  String label(_Step s) => axes.displayOf(
    s.axis,
    word.formLabels[word.formOrder.indexOf(s.to)].features,
  );
  String spelling(FormKey key) => word.forms[word.formOrder.indexOf(key)];
  final target = steps.last.to;
  final targetIndex = word.formOrder.indexOf(target);
  assert(bundleOf(word, target) == bundle);
  return Exercise(
    wordCardId: word.id,
    grammarCardId: GrammarCardId(word.dataFileId, bundle),
    kind: kind,
    questionKey: questionKey,
    questionParams: {
      'start': spelling(steps.first.from),
      'word': word.lemma,
      'changes': steps.map(label).join(' → '),
    },
    answer: TypedAnswer(
      FormOption(
        text: word.forms[targetIndex],
        formKey: target,
        lexemeId: word.id,
      ),
      word.acceptedForms[targetIndex],
    ),
  );
}

List<FormKey> _bundleKeys(
  PracticeItem word,
  GrammarBundle bundle,
  ExerciseContext ctx,
) {
  if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
  final keys = [
    for (final key in word.formOrder)
      if (bundleOf(word, key) == bundle) key,
  ];
  if (keys.isEmpty) throw CannotBuild('${word.id} has no form in $bundle');
  return keys;
}

/// Asks for the form that one axis change of a shown form gives.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// selection.
class TransformGenerator implements ExerciseGenerator {
  const TransformGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.umformen;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final steps = (_bundleKeys(word, bundle, ctx)..shuffle(rng))
        .expand((key) => _chains(word, key, 1, ctx.unlocked, rng))
        .firstOrNull;
    if (steps == null) {
      throw CannotBuild('${word.id} has no axis change into $bundle');
    }
    return _build(
      kind: kind,
      questionKey: 'exercise.transform.question',
      word: word,
      bundle: bundle,
      steps: steps,
    );
  }
}

/// Asks for the form that two or three axis changes in a row give.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// selection.
class FormChainGenerator implements ExerciseGenerator {
  const FormChainGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.formenKette;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final length = 2 + rng.nextInt(2);
    final steps = (_bundleKeys(word, bundle, ctx)..shuffle(rng))
        .expand((key) => _chains(word, key, length, ctx.unlocked, rng))
        .where(
          (chain) =>
              norm(word.forms[word.formOrder.indexOf(chain.first.from)]) !=
              norm(word.forms[word.formOrder.indexOf(chain.last.to)]),
        )
        .firstOrNull;
    if (steps == null) {
      throw CannotBuild('${word.id} has no $length-step chain into $bundle');
    }
    return _build(
      kind: kind,
      questionKey: 'exercise.transform.chainQuestion',
      word: word,
      bundle: bundle,
      steps: steps,
    );
  }
}
