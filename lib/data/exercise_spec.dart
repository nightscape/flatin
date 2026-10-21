/// An exercise kind as data: which cells of the word it asks, what it shows
/// and how the learner answers. The interpreter gives each variant its
/// meaning, so a spec holds no code.
library;

import '../models/exercise.dart';
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

/// A start cell and the target, reached by changing one of [axes] per step,
/// each axis at most once.
final class AxisPath extends Selection {
  final List<String> axes;

  /// The step counts a path may have.
  final Set<int> lengths;

  const AxisPath({required this.axes, required this.lengths});
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

/// The cell of a selection that a [Show] param shows.
enum Ref { target, start }

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
