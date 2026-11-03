import 'dart:math';

import 'package:fsrs/fsrs.dart';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';

typedef Attribution = ({Rating word, Rating? grammar});

const _good = (word: Rating.good, grammar: Rating.good);

/// Whether the response was right: both cards rated Good.
bool isRight(Attribution attribution) => attribution == _good;

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
  (final SortingAnswer answer, SortedForms(:final groupOf)) => _sorted(
    answer,
    groupOf,
  ),
  (final PartsAnswer answer, TypedTexts(:final texts)) => _parts(answer, texts),
  (final MarksAnswer answer, MarksResponse(:final wordOf)) => _marked(
    answer,
    wordOf,
  ),
  (final TickAnswer answer, TickedOptions(:final ticked)) => (
    word: tickRating(answer, ticked),
    grammar: tickRating(answer, ticked),
  ),
  _ => throw ArgumentError(
    '${response.runtimeType} does not answer ${exercise.answer.runtimeType}',
  ),
};

Attribution _typed(PracticeItem word, TypedAnswer answer, String text) {
  if (typedRight(answer, text)) return _good;
  return _byDiagnosis(diagnose(word, answer.expected.formKey, text));
}

/// The ratings one typed [text] for the form [key] of [word] gives.
/// Produced here; read by the paradigm screen.
Attribution attributeTypedRow(PracticeItem word, FormKey key, String text) =>
    word.accepts(word.formOrder.indexOf(key), text)
    ? _good
    : _byDiagnosis(diagnose(word, key, text));

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
/// a wrong pair is judged by the option it attached to the left one, or with
/// [MatchingAnswer.agreements] tells case, number or gender wrong.
Attribution _matched(
  PracticeItem word,
  MatchingAnswer answer,
  List<(FormOption, FormOption)> pairs,
) => answer.agreements != null
    ? pairs.every(
            (p) => answer.pairs.any(
              (r) => identical(r.$1, p.$1) && identical(r.$2, p.$2),
            ),
          )
          ? _good
          : (word: Rating.good, grammar: Rating.again)
    : _worst([
        for (final (left, attached) in pairs)
          _chosen(
            word,
            answer.pairs.singleWhere((p) => identical(p.$1, left)).$2,
            attached,
          ),
      ]);

/// A form in another group tells the bundles apart wrong, whichever word it
/// belongs to.
Attribution _sorted(SortingAnswer answer, Map<FormOption, int> groupOf) {
  assert(groupOf.length == answer.forms.length, 'a form has no group');
  return answer.forms.every((f) => groupOf[f.$1] == f.$2)
      ? _good
      : (word: Rating.good, grammar: Rating.again);
}

/// A wrong slot gets the row wrong, whichever part it is.
Attribution _parts(PartsAnswer answer, List<String> texts) {
  assert(texts.length == answer.slots.length, '${texts.length} texts');
  return answer.slots.indexed.every((e) => typedRight(e.$2.answer, texts[e.$1]))
      ? _good
      : (word: Rating.good, grammar: Rating.again);
}

/// A pill on another word counts 0: the share of right pills rates the
/// grammar.
Attribution _marked(MarksAnswer answer, List<int> wordOf) =>
    (word: Rating.good, grammar: shareRating(marksShare(answer, wordOf)));

/// The share of the pills on their right word.
double marksShare(MarksAnswer answer, List<int> wordOf) {
  assert(wordOf.length == answer.pills.length, 'a pill is not placed');
  final right = answer.pills.indexed
      .where((e) => wordOf[e.$1] == e.$2.word)
      .length;
  return right / answer.pills.length;
}

/// Good for the full share, Hard from half of it, Again below; never Easy.
Rating shareRating(double share) {
  assert(0 <= share && share <= 1, 'share $share');
  if (share == 1) return Rating.good;
  return share >= 0.5 ? Rating.hard : Rating.again;
}

/// The score of ticking [c] right and [w] wrong of [n] options, [k] of them
/// right, in points of one right answer; random extra ticks never raise its
/// expected value.
double tickScore({
  required int n,
  required int k,
  required int c,
  required int w,
}) {
  assert(1 <= k && 2 * k <= n, '$k of $n options are right');
  assert(0 <= c && c <= k && 0 <= w && w <= n - k, '$c right, $w wrong');
  final rho = (n + 1 - 2 * k) / (2 * (n - k));
  return c * pow(rho, w).toDouble();
}

Rating tickRating(TickAnswer answer, Set<int> ticked) =>
    shareRating(tickShare(answer, ticked));

/// The tick score of [ticked] in points of the best score `k`.
double tickShare(TickAnswer answer, Set<int> ticked) {
  final right = answer.right;
  return tickScore(
        n: answer.options.length,
        k: right.length,
        c: ticked.intersection(right).length,
        w: ticked.difference(right).length,
      ) /
      right.length;
}

/// Quarters of a right answer that [response] earns, 0..4; 0 for an answer
/// that rates no share.
int partialOf(ExerciseAnswer answer, ExerciseResponse response) =>
    switch ((answer, response)) {
      (final MarksAnswer a, MarksResponse(:final wordOf)) =>
        (4 * marksShare(a, wordOf)).floor(),
      (final TickAnswer a, TickedOptions(:final ticked)) =>
        (4 * tickShare(a, ticked)).floor(),
      _ => 0,
    };

/// Whether [text] is a spelling of [answer], read without macrons.
bool typedRight(TypedAnswer answer, String text) =>
    answer.accepted.any((s) => norm(s) == norm(text));

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
