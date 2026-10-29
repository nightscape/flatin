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
  final SortingAnswer answer => (rightSorting(answer), wrongSorting(answer)),
};

SortedForms rightSorting(SortingAnswer answer) =>
    SortedForms({for (final (o, g) in answer.forms) o: g});

/// The first form in the next group, the others in their own.
SortedForms wrongSorting(SortingAnswer answer) => SortedForms({
  for (final (i, (o, g)) in answer.forms.indexed)
    o: i == 0 ? (g + 1) % answer.groups.length : g,
});
