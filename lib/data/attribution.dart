import 'package:fsrs/fsrs.dart';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';

typedef Attribution = ({Rating word, Rating? grammar});

const _good = (word: Rating.good, grammar: Rating.good);

/// The ratings one [response] to [exercise] of [word] gives the word card and
/// the grammar card; `grammar` is null when the response says nothing about
/// the bundle.
/// Produced here from the exercise and the diagnosis; read by the review step.
Attribution attribute(
  PracticeItem word,
  Exercise exercise,
  ExerciseResponse response,
) => switch ((exercise.answer, response)) {
  (final TypedAnswer answer, TypedText(:final text)) => _typed(
    word,
    answer,
    text,
  ),
  (final ChoiceAnswer answer, ChosenOption(:final chosen)) => _chosen(
    word,
    answer.right,
    chosen,
  ),
  (final MatchingAnswer answer, MatchedPairs(:final pairs)) => _matched(
    word,
    answer,
    pairs,
  ),
  _ => throw ArgumentError(
    '${response.runtimeType} does not answer ${exercise.answer.runtimeType}',
  ),
};

Attribution _typed(PracticeItem word, TypedAnswer answer, String text) {
  final given = norm(text);
  if (answer.accepted.any((s) => norm(s) == given)) return _good;
  return _byDiagnosis(diagnose(word, answer.expected.formKey, text));
}

Attribution _byDiagnosis(Diagnosis diagnosis) => switch (diagnosis) {
  OtherFormOfWord() ||
  EndingOfOtherType() => (word: Rating.good, grammar: Rating.again),
  WrongStem() ||
  RegularInsteadOfIrregular() => (word: Rating.again, grammar: Rating.good),
  NoMatch() => (word: Rating.again, grammar: Rating.again),
};

Attribution _chosen(PracticeItem word, FormOption right, FormOption chosen) {
  if (identical(chosen, right)) return _good;
  final diagnosis = chosen.builtWrongBy;
  if (diagnosis != null) return _byDiagnosis(diagnosis);
  if (chosen.lexemeId != word.id) return (word: Rating.again, grammar: null);
  return (word: Rating.good, grammar: Rating.again);
}

/// A pair is right when its [FormOption]s are the very ones of a right pair;
/// a wrong pair is judged by the option it attached to the left one.
Attribution _matched(
  PracticeItem word,
  MatchingAnswer answer,
  List<(FormOption, FormOption)> pairs,
) => _worst([
  for (final (left, attached) in pairs)
    _chosen(
      word,
      answer.pairs.singleWhere((p) => identical(p.$1, left)).$2,
      attached,
    ),
]);

Rating _worse(Rating a, Rating b) => a.value <= b.value ? a : b;

Attribution _worst(Iterable<Attribution> ratings) {
  final grammar = ratings.map((r) => r.grammar).nonNulls;
  return (
    word: ratings.map((r) => r.word).reduce(_worse),
    grammar: grammar.isEmpty ? null : grammar.reduce(_worse),
  );
}

/// One row of a paradigm screen: the bundle it belongs to and its ratings.
typedef ParadigmRow = ({GrammarBundle bundle, Attribution rating});

/// The word card gets the worst word rating of all rows; word ratings are
/// Good unless the row's diagnosis blames the word. Each bundle gets the worst
/// grammar rating of its rows; a bundle whose rows all say nothing is absent.
({Rating word, Map<GrammarBundle, Rating> grammar}) attributeParadigm(
  Iterable<ParadigmRow> rows,
) {
  final grammar = <GrammarBundle, Rating>{};
  for (final (:bundle, :rating) in rows) {
    final g = rating.grammar;
    if (g != null) {
      grammar.update(bundle, (r) => _worse(r, g), ifAbsent: () => g);
    }
  }
  return (
    word: rows.map((r) => r.rating.word).reduce(_worse),
    grammar: grammar,
  );
}
