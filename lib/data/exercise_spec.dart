/// An exercise kind as data: which cells of the word it asks, what it shows
/// and how the learner answers. The interpreter gives each variant its
/// meaning, so a spec holds no code.
library;

import '../models/exercise.dart';
import '../models/form_label.dart' show FormKey;
import 'exercise_cube.dart';

/// One kind of exercise.
/// Produced in `exercise_kinds.dart`; read by the interpreter.
final class KindSpec {
  final ExerciseKind kind;
  final String questionKey;
  final Selection select;

  /// The question params; their cells and texts are the prompt.
  final Map<String, Param> params;
  final AnswerSpec answer;

  const KindSpec({
    required this.kind,
    required this.questionKey,
    required this.select,
    required this.params,
    required this.answer,
  });
}

/// Which cells of the asked bundle an exercise is about.
sealed class Selection {
  const Selection();
}

/// One target cell.
final class OneCell extends Selection {
  const OneCell();
}

/// [majority] cells share the value of one axis; the target differs from one
/// of them on that axis only and is the only cell alone on any axis.
final class OddOneOut extends Selection {
  final int majority;

  /// Groups drawn before the build gives up.
  final int maxDraws;

  const OddOneOut({required this.majority, required this.maxDraws});
}

/// [n] cells of the bundle that no two can be taken for each other.
final class Sample extends Selection {
  final int n;

  const Sample({required this.n});
}

/// A start cell and the target, reached by changing one of [axes] per step,
/// each axis at most once.
final class AxisPath extends Selection {
  final List<String> axes;

  /// The step counts a path may have.
  final Set<int> lengths;

  const AxisPath({required this.axes, required this.lengths});
}

/// One target cell and a text that is no form of the word, built by one of
/// [ways] for the target's key.
final class Spoil extends Selection {
  final Set<SpoilWay> ways;

  const Spoil({required this.ways});
}

/// [count] cells of the context's words, each in one bundle of a set of
/// [sets] that holds the asked bundle; the target is a cell of the asked word
/// in the asked bundle. No cell reads like a cell of its word in another
/// bundle of the set.
final class LookAlikes extends Selection {
  /// Bundles whose forms look alike, in the order the learner reads them.
  final List<List<GrammarBundle>> sets;
  final ({int min, int max}) count;

  /// The most words the cells come from, the asked one included.
  final int words;

  const LookAlikes({
    required this.sets,
    required this.count,
    required this.words,
  });
}

/// The principal parts of a verb: the cells of [row] the word has and the
/// learner practises, in that order. While the part cards are not known well
/// the prompt is the first part and the rest of the row is asked; once they
/// are, the prompt is a practised form whose key starts with one of
/// [promptsFrom] and the whole row is asked. A row with a deponent part has
/// no [supine]: hortārī, hortor, hortātus sum.
final class PrincipalParts extends Selection {
  /// Each part's key and the i18n key of its name.
  final List<({FormKey key, String name})> row;
  final List<String> promptsFrom;
  final FormKey supine;

  /// The fewest distinct texts a row needs to be worth asking.
  final int minParts;

  const PrincipalParts({
    required this.row,
    required this.promptsFrom,
    required this.supine,
    required this.minParts,
  });
}

/// A sentence of the context's corpus the learner can see: of a lesson up to
/// the reached one, every form an unlocked cell of a pool word, its
/// construction kind's name in [constructions] when given.
final class OneSentence extends Selection {
  final Set<String>? constructions;

  const OneSentence({this.constructions});
}

/// How a [Spoil] builds its wrong text.
enum SpoilWay {
  /// The participle or the auxiliary of a two-word form, taken from the same
  /// form in the other number.
  compoundSwap,

  /// The word's stem with the ending another type uses for the key.
  otherTypeEnding,
}

/// One question param.
sealed class Param {
  const Param();
}

/// The shown text of a cell in a view.
final class Show extends Param {
  final Ref of;
  final View view;

  const Show(this.of, this.view);
}

/// The steps of an [AxisPath], e.g. "Perfekt → Plural".
final class AxisChanges extends Param {
  const AxisChanges();
}

/// The name of the target's bundle, e.g. "Indikativ Futur I Aktiv".
final class BundleName extends Param {
  const BundleName();
}

/// What a [Show] param shows of a selection: its target cell, the start of
/// its path or its spoiled text.
enum Ref { target, start, spoiled }

/// How the learner answers.
sealed class AnswerSpec {
  const AnswerSpec();
}

/// The learner picks the target among [count] options shown in [view].
final class Choose extends AnswerSpec {
  final View view;
  final OptionSource from;
  final int count;

  const Choose(this.view, {required this.from, required this.count});
}

/// The learner types the target in [view]; every cell the prompt can name is
/// right.
final class Typed extends AnswerSpec {
  final View view;

  const Typed(this.view);
}

/// The learner types the [view] text of every asked part of a
/// [PrincipalParts] row, one slot each.
final class Parts extends AnswerSpec {
  final View view;

  const Parts(this.view);
}

/// The learner pairs the [left] text of every sampled cell with its [right]
/// text, or for a word of an [agreeing] type with the [right] text of a noun
/// cell of the pool that agrees with it in case, number and gender.
final class Match extends AnswerSpec {
  final View left;
  final View right;
  final Set<String> agreeing;

  const Match(this.left, this.right, {this.agreeing = const {}});
}

/// The learner puts every selected cell, shown in [view], into the group of
/// its bundle; with [tick] the groups are the target's bundle and the rest,
/// and the learner ticks the first.
final class Sort extends AnswerSpec {
  final View view;
  final bool tick;

  const Sort(this.view, {required this.tick});
}

/// Where the wrong options of a [Choose] come from.
sealed class OptionSource {
  const OptionSource();
}

/// Cells of the word that differ from the target on [k] axes, and with
/// [withBuiltWrong] the wrong texts built for the target's key.
final class Neighbours extends OptionSource {
  final int k;
  final bool withBuiltWrong;

  const Neighbours({required this.k, required this.withBuiltWrong});
}

/// The selected group itself.
final class TheSelection extends OptionSource {
  const TheSelection();
}
