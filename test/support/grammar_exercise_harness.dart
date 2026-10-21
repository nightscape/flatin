import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

/// A right response to [exercise] of [word] and a wrong one.
(ExerciseResponse, ExerciseResponse) rightAndWrong(
  PracticeItem word,
  Exercise exercise,
) => switch (exercise.answer) {
  ChoiceAnswer(:final options, :final right) => (
    ChosenOption(right),
    ChosenOption(options.firstWhere((o) => !identical(o, right))),
  ),
  TypedAnswer(:final expected, :final accepted) => (
    TypedText(expected.text),
    TypedText(
      word.forms.firstWhere((f) => !accepted.any((a) => norm(a) == norm(f))),
    ),
  ),
  MatchingAnswer(:final pairs) => (
    MatchedPairs(pairs),
    MatchedPairs([
      for (final (i, (left, _)) in pairs.indexed)
        (left, pairs[(i + 1) % pairs.length].$2),
    ]),
  ),
};
