import 'dart:math';

import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart' show OneSentence;
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'exercise_invariants.dart';
import '../support/latin_course.dart' show latinLaterLesson;

/// Every [stride]th word of [items] with all its bundles, asked through every
/// shipped generator that can build there, one exercise per seed. With
/// [stabilityOf] the words count as learned, else as new.
List<(PracticeItem, Exercise)> drawExercises(
  List<PracticeItem> items,
  GermanForms german,
  SentenceCorpus corpus, {
  required int stride,
  int seeds = 1,
  double? Function(String id)? stabilityOf,
}) {
  final everyBundle = {
    for (final w in items)
      for (final k in w.formOrder) bundleOf(w, k),
  };
  final drawn = <(PracticeItem, Exercise)>[];
  for (var i = 0; i < items.length; i += stride) {
    final word = items[i];
    for (final bundle in {for (final k in word.formOrder) bundleOf(word, k)}) {
      for (final g in exerciseGenerators) {
        final ctx = g.spec.select is OneSentence
            ? ExerciseContext(
                unlocked: everyBundle,
                pool: items,
                german: german,
                sentences: corpus,
                reachedLesson: latinLaterLesson,
              )
            : ExerciseContext(
                unlocked: unlockedFor(g.spec, word, bundle),
                pool: [word],
                german: german,
                stabilityOf: stabilityOf ?? (_) => null,
              );
        for (var seed = 0; seed < seeds; seed++) {
          try {
            drawn.add((word, g.build(word, bundle, ctx, Random(seed))));
          } on CannotBuild {
            continue;
          }
        }
      }
    }
  }
  return drawn;
}

/// The Latin texts the learner has to produce or pick; empty for a task that
/// asks no Latin text.
Set<String> expectedLatin(Exercise e) => switch (e.answer) {
  TypedAnswer(:final accepted) => {...accepted},
  ChoiceAnswer(:final right) => {right.text},
  PartsAnswer(:final slots) => {for (final s in slots) ...s.answer.accepted},
  MatchingAnswer() ||
  SortingAnswer() ||
  MarksAnswer() ||
  TickAnswer() => const {},
};

/// Whether [e] shows a split form of more than one word.
bool showsMultiWordSplit(Exercise e) =>
    e.stemSplits.keys.any((k) => e.questionParams[k]!.contains(' '));

/// [drawExercises] at [stride], plus every exercise of the first three words
/// that have a split form of more than one word: a stride draw reaches such a
/// form at a prompt too rarely.
List<(PracticeItem, Exercise)> drawPromptExercises(
  List<PracticeItem> items,
  GermanForms german,
  SentenceCorpus corpus, {
  required int stride,
}) => [
  ...drawExercises(items, german, corpus, stride: stride),
  ...drawExercises(
    [
      for (final w in items)
        if ([
          for (var i = 0; i < w.forms.length; i++)
            if (w.forms[i].contains(' '))
              w.derivation.stemOf(w.formOrder[i], w.forms[i]),
        ].nonNulls.isNotEmpty)
          w,
    ].take(3).toList(),
    german,
    corpus,
    stride: 1,
  ),
];

/// The first of [drawn] per exercise kind and per [showsMultiWordSplit].
List<(PracticeItem, Exercise)> firstPerKindAndClass(
  Iterable<(PracticeItem, Exercise)> drawn,
) {
  final first = <(ExerciseKind, bool), (PracticeItem, Exercise)>{};
  for (final d in drawn) {
    first.putIfAbsent((d.$2.kind, showsMultiWordSplit(d.$2)), () => d);
  }
  return first.values.toList();
}
