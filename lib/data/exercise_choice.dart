/// Which kind of exercise asks a (word, bundle) pair: recognising while the
/// weaker card is unstable, building once it holds.
library;

import 'dart:math';

import '../models/course_filter.dart';
import '../models/exercise.dart';
import '../models/fsrs_card.dart';
import '../models/practice_item.dart';

enum KindClass { recognition, building }

KindClass classOf(ExerciseKind kind) => switch (kind) {
  ExerciseKind.bestimmen ||
  ExerciseKind.latDeWahl ||
  ExerciseKind.deLatWahl ||
  ExerciseKind.irrlaeufer ||
  ExerciseKind.zuordnen => KindClass.recognition,
  ExerciseKind.formBilden ||
  ExerciseKind.deLatTippen ||
  ExerciseKind.umformen ||
  ExerciseKind.fehlerFinden ||
  ExerciseKind.formenKette ||
  ExerciseKind.paradigma => KindClass.building,
};

/// From each lower bound of the FSRS stability in days, the chance that the
/// building class is asked. A new card has stability 0, a first Good gives
/// about 2.3 days and a second one about 10, so a word moves from recognising
/// through a mixed band to building in about two good reviews.
const buildingChanceFrom = <({double stability, double chance})>[
  (stability: 0, chance: 0),
  (stability: 2, chance: 0.5),
  (stability: 7, chance: 1),
];

/// The class to ask first for a pair whose weaker card has [stability].
KindClass classFor(double stability, Random rng) {
  assert(stability >= 0, 'stability $stability is negative');
  final chance = buildingChanceFrom
      .lastWhere((row) => stability >= row.stability)
      .chance;
  return rng.nextDouble() < chance ? KindClass.building : KindClass.recognition;
}

/// The stability of the weaker of [a] and [b]; a card never reviewed has 0.
double weakerStability(PracticeItemCard a, PracticeItemCard b) =>
    min(a.card.stability ?? 0, b.card.stability ?? 0);

/// The bundles of the forms that [filter] practises in [items].
Set<GrammarBundle> unlockedBundles(
  CourseFilter filter,
  Iterable<PracticeItem> items,
) => {
  for (final item in items)
    for (final label in item.formLabels)
      if (filter.formPracticed(item.dataFileId, label))
        bundleOf(item, label.key),
};

/// Builds an exercise for [word] in [bundle]: the kinds of [registry] in the
/// class [classFor] picks, in random order, then those of the other class;
/// kinds in [avoid] come after all others. A
/// kind that throws [CannotBuild] does not fit the word, so the next is tried.
///
/// Throws an [AssertionError] naming the pair when no kind fits: a data or
/// generator bug, as every pair the selection offers must be askable.
Exercise buildExercise(
  PracticeItem word,
  GrammarBundle bundle,
  ExerciseContext ctx,
  double stability,
  Random rng, {
  List<ExerciseGenerator> registry = exerciseGenerators,
  Set<ExerciseKind> avoid = const {},
}) {
  final first = classFor(stability, rng);
  List<ExerciseGenerator> ofClass(bool isFirst) => [
    for (final g in registry)
      if ((classOf(g.kind) == first) == isFirst) g,
  ]..shuffle(rng);
  final reasons = <String>[];
  final order = [...ofClass(true), ...ofClass(false)];
  for (final generator in [
    ...order.where((g) => !avoid.contains(g.kind)),
    ...order.where((g) => avoid.contains(g.kind)),
  ]) {
    try {
      return generator.build(word, bundle, ctx, rng);
    } on CannotBuild catch (e) {
      reasons.add('${generator.kind.name}: ${e.reason}');
    }
  }
  throw AssertionError(
    'no exercise kind fits ${word.id} in $bundle (${reasons.join('; ')})',
  );
}
