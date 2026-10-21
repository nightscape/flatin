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
];

final List<SpecGenerator> specGenerators = [
  for (final spec in kindSpecs) SpecGenerator(spec),
];
