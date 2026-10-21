import 'dart:math';

import 'package:fsrs/fsrs.dart';

import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'attribution.dart';

/// One task of a round: [exercise] asks [word] in [bundle]; [isRetry] marks a
/// task that comes back after a wrong answer.
/// Produced by the round planner and [answer]; read by the round screen.
final class RoundTask {
  final PracticeItem word;
  final GrammarBundle bundle;
  final Exercise exercise;
  final bool isRetry;

  const RoundTask(
    this.word,
    this.bundle,
    this.exercise, {
    this.isRetry = false,
  });
}

/// The state of one round; [answer] returns the next one.
/// Produced by [startRound] and [answer]; read by the round screen.
final class RoundState {
  /// The planned first tasks, 1..10.
  final int total;
  final int answeredFirst;

  /// The tasks still to answer; `queue.first` is the current one.
  final List<RoundTask> queue;

  /// The ratings of the counted first attempts per grammar card.
  final Map<GrammarCardId, List<Rating>> grammarFirst;

  const RoundState({
    required this.total,
    required this.answeredFirst,
    required this.queue,
    required this.grammarFirst,
  });

  bool get isOver => queue.isEmpty;

  /// The n of "Aufgabe n von total"; stays at [total] during retries.
  int get shownNumber => min(answeredFirst + 1, total);

  bool get inRetries => !isOver && queue.first.isRetry;
}

/// [wordRating] is null on a retry: a word is reviewed once per task.
typedef AnswerOutcome = ({bool right, bool firstAttempt, Rating? wordRating});

RoundState startRound(List<RoundTask> tasks) {
  assert(tasks.isNotEmpty && tasks.length <= 10, '${tasks.length} tasks');
  return RoundState(
    total: tasks.length,
    answeredFirst: 0,
    queue: List.unmodifiable(tasks),
    grammarFirst: const {},
  );
}

/// Answers the current task. A wrong answer queues the task built by [retry]
/// at the end; the round is over when every task was right once.
(RoundState, AnswerOutcome) answer(
  RoundState state,
  Attribution attribution,
  Exercise Function(RoundTask failed) retry,
) {
  assert(!state.isOver);
  final task = state.queue.first;
  final right = isRight(attribution);
  final firstAttempt = !task.isRetry;
  final grammar = attribution.grammar;
  final grammarFirst = {
    for (final e in state.grammarFirst.entries) e.key: [...e.value],
  };
  if (firstAttempt && grammar != null) {
    grammarFirst
        .putIfAbsent(GrammarCardId(task.word.dataFileId, task.bundle), () => [])
        .add(grammar);
  }
  final next = RoundState(
    total: state.total,
    answeredFirst: state.answeredFirst + (firstAttempt ? 1 : 0),
    queue: List.unmodifiable([
      ...state.queue.skip(1),
      if (!right) RoundTask(task.word, task.bundle, retry(task), isRetry: true),
    ]),
    grammarFirst: grammarFirst,
  );
  return (
    next,
    (
      right: right,
      firstAttempt: firstAttempt,
      wordRating: firstAttempt ? attribution.word : null,
    ),
  );
}

/// n = counted first attempts of a bundle, e = those rated Again. All right is
/// Good; half or more Again is Again; anything between is Hard.
Rating aggregate(List<Rating> firstAttempts) {
  assert(firstAttempts.isNotEmpty);
  final e = firstAttempts.where((r) => r == Rating.again).length;
  if (e == 0) return Rating.good;
  if (2 * e >= firstAttempts.length) return Rating.again;
  return Rating.hard;
}

/// One rating per grammar card with a counted first attempt.
Map<GrammarCardId, Rating> bundleRatings(RoundState finished) {
  assert(finished.isOver);
  return {
    for (final e in finished.grammarFirst.entries) e.key: aggregate(e.value),
  };
}
