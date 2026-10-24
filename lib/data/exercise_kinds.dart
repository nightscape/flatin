/// The exercise kinds that run from a spec.
library;

import '../models/exercise.dart';
import 'exercise_cube.dart';
import 'exercise_interpreter.dart';
import 'exercise_spec.dart';

const kindSpecs = [
  KindSpec(
    kind: ExerciseKind.latDeWahl,
    questionKey: 'exercise.translate.latDe.question',
    select: OneCell(),
    params: {
      'form': Show(Ref.target, View.latin),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Choose(
      View.german,
      from: Neighbours(k: 1, withBuiltWrong: true),
      count: 4,
    ),
  ),
  KindSpec(
    kind: ExerciseKind.deLatWahl,
    questionKey: 'exercise.translate.deLat.question',
    select: OneCell(),
    params: {
      'german': Show(Ref.target, View.german),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Choose(
      View.latin,
      from: Neighbours(k: 1, withBuiltWrong: true),
      count: 4,
    ),
  ),
  KindSpec(
    kind: ExerciseKind.deLatTippen,
    questionKey: 'exercise.translate.deLatType.question',
    select: OneCell(),
    params: {
      'german': Show(Ref.target, View.german),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Typed(View.latin),
  ),
  KindSpec(
    kind: ExerciseKind.formBilden,
    questionKey: 'exercise.build.question',
    select: OneCell(),
    params: {
      'label': Show(Ref.target, View.label),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Typed(View.latin),
  ),
  KindSpec(
    kind: ExerciseKind.irrlaeufer,
    questionKey: 'exercise.oddone.question',
    select: OddOneOut(majority: 3, maxDraws: 200),
    params: {},
    answer: Choose(View.latin, from: TheSelection(), count: 4),
  ),
  KindSpec(
    kind: ExerciseKind.umformen,
    questionKey: 'exercise.transform.question',
    select: AxisPath(axes: ['genus_verbi', 'tempus', 'numerus'], lengths: {1}),
    params: {
      'start': Show(Ref.start, View.latin),
      'word': Show(Ref.target, View.lemma),
      'changes': AxisChanges(),
    },
    answer: Typed(View.latin),
  ),
  KindSpec(
    kind: ExerciseKind.fehlerFinden,
    questionKey: 'exercise.finderror.question',
    select: Spoil(ways: {SpoilWay.compoundSwap, SpoilWay.otherTypeEnding}),
    params: {
      'label': Show(Ref.target, View.label),
      'word': Show(Ref.target, View.lemma),
      'wrong': Show(Ref.spoiled, View.latin),
    },
    answer: Typed(View.latin),
  ),
  KindSpec(
    kind: ExerciseKind.bestimmen,
    questionKey: 'exercise.bestimmen.question',
    select: OneCell(),
    params: {
      'form': Show(Ref.target, View.latin),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Choose(
      View.label,
      from: Neighbours(k: 1, withBuiltWrong: false),
      count: 4,
    ),
  ),
  KindSpec(
    kind: ExerciseKind.zuordnen,
    questionKey: 'exercise.match.question',
    select: Sample(n: 4),
    params: {'word': Show(Ref.target, View.lemma)},
    answer: Match(View.latin, View.german),
  ),
  KindSpec(
    kind: ExerciseKind.formenKette,
    questionKey: 'exercise.transform.chainQuestion',
    select: AxisPath(
      axes: ['genus_verbi', 'tempus', 'numerus'],
      lengths: {2, 3},
    ),
    params: {
      'start': Show(Ref.start, View.latin),
      'word': Show(Ref.target, View.lemma),
      'changes': AxisChanges(),
    },
    answer: Typed(View.latin),
  ),
];

/// The generators the app ships, one per kind. They are stateless: everything
/// that varies per call comes from [ExerciseContext].
final List<SpecGenerator> exerciseGenerators = [
  for (final spec in kindSpecs) SpecGenerator(spec),
];
