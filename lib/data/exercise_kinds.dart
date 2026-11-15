/// The exercise kinds that run from a spec.
library;

import '../models/derivation.dart' show FileRoles;
import '../models/exercise.dart';
import 'exercise_cube.dart';
import 'exercise_interpreter.dart';
import 'exercise_spec.dart';
import 'sentences.dart' show ConstructionKind;

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
    select: AxisPath(lengths: {1}),
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
    select: AxisPath(lengths: {2, 3}),
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
    select: LookAlikes(setName: 'tick', count: (min: 8, max: 12), words: 4),
    params: {'group': BundleName()},
    answer: Sort(View.latin, tick: true),
  ),
  KindSpec(
    kind: ExerciseKind.sortieren,
    questionKey: 'exercise.sort.question',
    select: LookAlikes(setName: 'sort', count: (min: 9, max: 12), words: 4),
    params: {},
    answer: Sort(View.latin, tick: false),
  ),
  KindSpec(
    kind: ExerciseKind.stammformen,
    questionKey: 'exercise.stammformen.question',
    select: PrincipalParts(minParts: 3),
    params: {'form': Show(Ref.target, View.latin)},
    answer: Parts(View.latin),
  ),
  KindSpec(
    kind: ExerciseKind.markieren,
    questionKey: 'exercise.tap.question',
    // A question marks only its particle, so it has no second word to tell.
    select: OneSentence(
      constructions: {'pcPpa', 'pcPpp', 'aciPassiv', 'doppelterAkkusativ'},
    ),
    params: {},
    answer: Marks({
      ConstructionKind.pcPpa: (head: 'participle', reference: 'reference'),
      ConstructionKind.pcPpp: (head: 'participle', reference: 'reference'),
      ConstructionKind.aciPassiv: (head: 'participle', reference: 'subject'),
      ConstructionKind.doppelterAkkusativ: (
        head: 'predicative',
        reference: 'object',
      ),
    }),
  ),
  KindSpec(
    kind: ExerciseKind.satzAnkreuzen,
    questionKey: 'exercise.ticks.question',
    select: OneSentence(),
    params: {'sentence': SentenceText()},
    answer: TickMany(count: 4),
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
    answer: Match(View.latin, View.latin, agreeing: true),
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

/// Refuses a kind that asks for a look-alike set that no file of the verb
/// role declares: its exercises would silently never be built.
void checkLookAlikeSets(Iterable<FileRoles> verbFiles) {
  final declared = {for (final file in verbFiles) ...file.lookAlikes.keys};
  for (final spec in [
    ...kindSpecs,
    ...vocabSpecs.values,
    ...agreementSpecs.values,
  ]) {
    if (spec.select case LookAlikes(
      :final setName,
    ) when !declared.contains(setName)) {
      throw StateError(
        '${spec.kind.name} asks for the look-alike set "$setName", which no '
        'verb data file declares',
      );
    }
  }
}
