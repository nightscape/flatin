/// The exercise kinds that run from a spec.
library;

import '../models/derivation.dart' show FileRoles;
import '../models/exercise.dart';
import 'exercise_cube.dart';
import 'exercise_interpreter.dart';
import 'exercise_spec.dart';

const kindSpecs = [
  KindSpec(
    kind: ExerciseKind.bedeutungWahl,
    questionKey: 'exercise.bedeutungWahl.question',
    select: OneCell(),
    params: {
      'form': Show(Ref.target, View.form),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Choose(
      View.meaning,
      from: Neighbours(k: 1, withBuiltWrong: true),
      count: 4,
    ),
  ),
  KindSpec(
    kind: ExerciseKind.formWahl,
    questionKey: 'exercise.formWahl.question',
    select: OneCell(),
    params: {
      'german': Show(Ref.target, View.meaning),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Choose(
      View.form,
      from: Neighbours(k: 1, withBuiltWrong: true),
      count: 4,
    ),
  ),
  KindSpec(
    kind: ExerciseKind.formTippen,
    questionKey: 'exercise.formTippen.question',
    select: OneCell(),
    params: {
      'german': Show(Ref.target, View.meaning),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Typed(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.formBilden,
    questionKey: 'exercise.formBilden.question',
    select: OneCell(),
    params: {
      'label': Show(Ref.target, View.label),
      'word': Show(Ref.target, View.lemma),
    },
    answer: Typed(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.irrlaeufer,
    questionKey: 'exercise.irrlaeufer.question',
    select: OddOneOut(majority: 3, maxDraws: 200),
    params: {},
    answer: Choose(View.form, from: TheSelection(), count: 4),
  ),
  KindSpec(
    kind: ExerciseKind.umformen,
    questionKey: 'exercise.umformen.question',
    select: AxisPath(lengths: {1}),
    params: {
      'start': Show(Ref.start, View.form),
      'word': Show(Ref.target, View.lemma),
      'changes': AxisChanges(),
    },
    answer: Typed(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.fehlerFinden,
    questionKey: 'exercise.fehlerFinden.question',
    select: Spoil(ways: {SpoilWay.compoundSwap, SpoilWay.otherTypeEnding}),
    params: {
      'label': Show(Ref.target, View.label),
      'word': Show(Ref.target, View.lemma),
      'wrong': Show(Ref.spoiled, View.form),
    },
    answer: Typed(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.bestimmen,
    questionKey: 'exercise.bestimmen.question',
    select: OneCell(),
    params: {
      'form': Show(Ref.target, View.form),
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
    questionKey: 'exercise.zuordnen.question',
    select: Sample(n: 4),
    params: {'word': Show(Ref.target, View.lemma)},
    answer: Match(View.form, View.meaning),
  ),
  KindSpec(
    kind: ExerciseKind.formenKette,
    questionKey: 'exercise.formenKette.question',
    select: AxisPath(lengths: {2, 3}),
    params: {
      'start': Show(Ref.start, View.form),
      'word': Show(Ref.target, View.lemma),
      'changes': AxisChanges(),
    },
    answer: Typed(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.ankreuzen,
    questionKey: 'exercise.ankreuzen.question',
    select: LookAlikes(setName: 'tick', count: (min: 8, max: 12), words: 4),
    params: {'group': BundleName()},
    answer: Sort(View.form, tick: true),
  ),
  KindSpec(
    kind: ExerciseKind.sortieren,
    questionKey: 'exercise.sortieren.question',
    select: LookAlikes(setName: 'sort', count: (min: 9, max: 12), words: 4),
    params: {},
    answer: Sort(View.form, tick: false),
  ),
  KindSpec(
    kind: ExerciseKind.stammformen,
    questionKey: 'exercise.stammformen.question',
    select: PrincipalParts(minParts: 3),
    params: {'form': Show(Ref.target, View.form)},
    answer: Parts(View.form),
  ),
  KindSpec(
    kind: ExerciseKind.markieren,
    questionKey: 'exercise.markieren.question',
    // A question marks only its particle, so it has no second word to tell.
    select: OneSentence(withRoles: true),
    params: {},
    answer: Marks(),
  ),
  KindSpec(
    kind: ExerciseKind.satzAnkreuzen,
    questionKey: 'exercise.satzAnkreuzen.question',
    select: OneSentence(),
    params: {'sentence': SentenceText()},
    answer: TickMany(count: 4),
  ),
];

/// How the translation kinds ask a vocab item: its meaning, with the other
/// vocab items as the wrong options. No other kind asks one.
const vocabSpecs = {
  ExerciseKind.bedeutungWahl: KindSpec(
    kind: ExerciseKind.bedeutungWahl,
    questionKey: 'exercise.bedeutungWahl.vocab.question',
    select: OneCell(),
    params: {'word': Show(Ref.target, View.form)},
    answer: Choose(
      View.meaning,
      from: Neighbours(k: 0, withBuiltWrong: false),
      count: 4,
    ),
  ),
  ExerciseKind.formWahl: KindSpec(
    kind: ExerciseKind.formWahl,
    questionKey: 'exercise.formWahl.vocab.question',
    select: OneCell(),
    params: {'german': Show(Ref.target, View.meaning)},
    answer: Choose(
      View.form,
      from: Neighbours(k: 0, withBuiltWrong: false),
      count: 4,
    ),
  ),
  ExerciseKind.formTippen: KindSpec(
    kind: ExerciseKind.formTippen,
    questionKey: 'exercise.formTippen.vocab.question',
    select: OneCell(),
    params: {'german': Show(Ref.target, View.meaning)},
    answer: Typed(View.form),
  ),
  ExerciseKind.zuordnen: KindSpec(
    kind: ExerciseKind.zuordnen,
    questionKey: 'exercise.zuordnen.vocab.question',
    select: Sample(n: 4),
    params: {},
    answer: Match(View.form, View.meaning),
  ),
};

/// How a kind asks, beside its own way, a pronoun or adjective that stands
/// next to a noun: the forms of the word with the noun forms they agree with.
const agreementSpecs = {
  ExerciseKind.zuordnen: KindSpec(
    kind: ExerciseKind.zuordnen,
    questionKey: 'exercise.zuordnen.agree.question',
    select: Sample(n: 4),
    params: {},
    answer: Match(View.form, View.form, agreeing: true),
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
