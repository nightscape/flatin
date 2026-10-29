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
  KindSpec(
    kind: ExerciseKind.ankreuzen,
    questionKey: 'exercise.tick.question',
    select: LookAlikes(
      sets: [
        ['ind.impf.akt', 'ind.fut.akt'],
        ['ind.fut.akt', 'ind.praes.pass'],
      ],
      count: (min: 8, max: 12),
      words: 4,
    ),
    params: {'group': BundleName()},
    answer: Sort(View.latin, tick: true),
  ),
  KindSpec(
    kind: ExerciseKind.sortieren,
    questionKey: 'exercise.sort.question',
    select: LookAlikes(
      sets: [
        ['ind.perf.akt', 'ind.plusq.akt', 'ind.fut2.akt'],
      ],
      count: (min: 9, max: 12),
      words: 4,
    ),
    params: {},
    answer: Sort(View.latin, tick: false),
  ),
  KindSpec(
    kind: ExerciseKind.stammformen,
    questionKey: 'exercise.stammformen.question',
    select: PrincipalParts(
      row: [
        (key: 'inf.praes.akt', name: 'exercise.stammformen.part.infinitive'),
        (key: 'ind.praes.akt.1.sg', name: 'exercise.stammformen.part.present'),
        (key: 'ind.perf.akt.1.sg', name: 'exercise.stammformen.part.perfect'),
        (key: 'sup.akk', name: 'exercise.stammformen.part.supine'),
      ],
      promptsFrom: ['ind.perf.akt.1.sg', 'sup.akk', 'part.perf.'],
      supine: 'sup.akk',
      minParts: 3,
    ),
    params: {'form': Show(Ref.target, View.latin)},
    answer: Parts(View.latin),
  ),
];

/// How the translation kinds ask a vocab item: its meaning, with the other
/// vocab items as the wrong options. No other kind asks one.
const vocabSpecs = {
  ExerciseKind.latDeWahl: KindSpec(
    kind: ExerciseKind.latDeWahl,
    questionKey: 'exercise.vocab.latDe.question',
    select: OneCell(),
    params: {'word': Show(Ref.target, View.latin)},
    answer: Choose(
      View.german,
      from: Neighbours(k: 0, withBuiltWrong: false),
      count: 4,
    ),
  ),
  ExerciseKind.deLatWahl: KindSpec(
    kind: ExerciseKind.deLatWahl,
    questionKey: 'exercise.vocab.deLat.question',
    select: OneCell(),
    params: {'german': Show(Ref.target, View.german)},
    answer: Choose(
      View.latin,
      from: Neighbours(k: 0, withBuiltWrong: false),
      count: 4,
    ),
  ),
  ExerciseKind.deLatTippen: KindSpec(
    kind: ExerciseKind.deLatTippen,
    questionKey: 'exercise.vocab.deLatType.question',
    select: OneCell(),
    params: {'german': Show(Ref.target, View.german)},
    answer: Typed(View.latin),
  ),
  ExerciseKind.zuordnen: KindSpec(
    kind: ExerciseKind.zuordnen,
    questionKey: 'exercise.vocab.match.question',
    select: Sample(n: 4),
    params: {},
    answer: Match(View.latin, View.german),
  ),
};

/// How a kind asks, beside its own way, a pronoun or adjective that stands
/// next to a noun: the forms of the word with the noun forms they agree with.
const agreementSpecs = {
  ExerciseKind.zuordnen: KindSpec(
    kind: ExerciseKind.zuordnen,
    questionKey: 'exercise.agree.question',
    select: Sample(n: 4),
    params: {},
    answer: Match(
      View.latin,
      View.latin,
      agreeing: {
        'Pronomen-hic',
        'Pronomen-ille',
        'Pronomen-iste',
        'Pronomen-ipse',
        'Pronomen-idem',
        'Adjektiv-a-o',
        'Adjektiv-a-o-er',
        'Adjektiv-zweiendig',
        'Adjektiv-dreiendig',
        'Adjektiv-einendig-i',
        'Adjektiv-einendig-Konsonantstamm',
      },
    ),
  ),
};

/// The generators the app ships, one per kind. They are stateless: everything
/// that varies per call comes from [ExerciseContext].
final List<SpecGenerator> exerciseGenerators = [
  for (final spec in kindSpecs)
    SpecGenerator(
      spec,
      vocab: vocabSpecs[spec.kind],
      agreement: agreementSpecs[spec.kind],
    ),
];
