import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/round.dart';
import 'package:latin_practice/models/exercise.dart';

import 'support/hand_items.dart';

const _right = (word: Rating.good, grammar: Rating.good);
const _wrong = (word: Rating.again, grammar: Rating.again);
const _wordOnly = (word: Rating.again, grammar: null);
const _grammarOnly = (word: Rating.good, grammar: Rating.again);

final _word = handItem(
  dataFileId: 'verbs',
  lemma: 'vocare',
  axes: fullVerbAxes,
  forms: {
    'ind.perf.akt.2.pl': ['vocavistis'],
  },
);

Exercise _exercise(GrammarBundle bundle, ExerciseKind kind) {
  final options = [
    for (final text in ['a', 'b'])
      FormOption(text: text, formKey: 'ind.perf.akt.2.pl', lexemeId: _word.id),
  ];
  return Exercise(
    wordCardId: _word.id,
    grammarCardId: GrammarCardId('verbs', bundle),
    kind: kind,
    questionKey: 'q',
    answer: ChoiceAnswer(options, options.first),
  );
}

RoundTask _task(GrammarBundle bundle) =>
    RoundTask(_word, bundle, _exercise(bundle, ExerciseKind.latDeWahl));

List<RoundTask> _tasks(int n, [int bundles = 1]) => [
  for (var i = 0; i < n; i++) _task('b${i % bundles}'),
];

Exercise _retry(RoundTask failed) =>
    _exercise(failed.bundle, ExerciseKind.deLatWahl);

(RoundState, AnswerOutcome) _answer(RoundState s, Attribution a) =>
    answer(s, a, _retry);

void main() {
  group('round', () {
    test('all right: over after ten, no retry, numbers 1 to 10', () {
      var state = startRound(_tasks(10));
      for (var i = 1; i <= 10; i++) {
        expect(state.shownNumber, i);
        expect(state.inRetries, isFalse);
        final (next, outcome) = _answer(state, _right);
        expect(outcome, (
          right: true,
          firstAttempt: true,
          wordRating: Rating.good,
        ));
        state = next;
      }
      expect(state.isOver, isTrue);
      expect(state.shownNumber, 10);
    });

    test('a wrong first answer queues one retry at the end', () {
      var state = startRound(_tasks(5));
      for (var i = 0; i < 2; i++) {
        state = _answer(state, _right).$1;
      }
      final (next, outcome) = _answer(state, _wrong);
      expect(outcome, (
        right: false,
        firstAttempt: true,
        wordRating: Rating.again,
      ));
      expect(next.queue, hasLength(3));
      expect(next.queue.where((t) => t.isRetry), hasLength(1));
      final retry = next.queue.last;
      expect(retry.isRetry, isTrue);
      expect(retry.word, _word);
      expect(retry.bundle, 'b0');
      expect(retry.exercise.kind, ExerciseKind.deLatWahl);
      expect(next.answeredFirst, 3);
    });

    test(
      'a retry gives no word rating, and a wrong retry is appended again',
      () {
        var state = startRound(_tasks(1));
        state = _answer(state, _wrong).$1;
        expect(state.inRetries, isTrue);
        var (next, outcome) = _answer(state, _wrong);
        expect(outcome, (right: false, firstAttempt: false, wordRating: null));
        expect(next.queue, hasLength(1));
        expect(next.queue.single.isRetry, isTrue);
        expect(next.answeredFirst, 1);
        (next, outcome) = _answer(next, _right);
        expect(outcome, (right: true, firstAttempt: false, wordRating: null));
        expect(next.isOver, isTrue);
        expect(next.inRetries, isFalse);
      },
    );

    test('shownNumber stays at total during retries', () {
      var state = startRound(_tasks(3));
      for (var i = 0; i < 3; i++) {
        state = _answer(state, _wrong).$1;
      }
      expect(state.inRetries, isTrue);
      expect(state.shownNumber, 3);
    });

    test('a null grammar rating is not counted', () {
      var state = startRound(_tasks(2));
      state = _answer(state, _wordOnly).$1;
      expect(state.grammarFirst, isEmpty);
      state = _answer(state, _grammarOnly).$1;
      expect(state.grammarFirst.values.single, [Rating.again]);
    });

    test('retries do not count for the grammar card', () {
      var state = startRound(_tasks(1));
      state = _answer(state, _wrong).$1;
      state = _answer(state, _grammarOnly).$1;
      state = _answer(state, _right).$1;
      expect(bundleRatings(state).values.single, Rating.again);
      expect(state.grammarFirst.values.single, hasLength(1));
    });

    test('state is immutable', () {
      final start = startRound(_tasks(2));
      _answer(start, _wrong);
      expect(start.queue, hasLength(2));
      expect(start.answeredFirst, 0);
      expect(start.grammarFirst, isEmpty);
    });

    test('startRound rejects zero and eleven tasks', () {
      expect(() => startRound([]), throwsA(isA<AssertionError>()));
      expect(() => startRound(_tasks(11)), throwsA(isA<AssertionError>()));
    });

    test('bundleRatings asserts when the round is not over', () {
      expect(
        () => bundleRatings(startRound(_tasks(1))),
        throwsA(isA<AssertionError>()),
      );
    });

    test('answer asserts when the round is over', () {
      final over = _answer(startRound(_tasks(1)), _right).$1;
      expect(() => _answer(over, _right), throwsA(isA<AssertionError>()));
    });
  });

  group('aggregate', () {
    const g = Rating.good;
    const a = Rating.again;
    test('table', () {
      expect(aggregate([g]), Rating.good);
      expect(aggregate([a]), Rating.again);
      expect(aggregate([g, g, g, a]), Rating.hard);
      expect(aggregate([g, a]), Rating.again);
      expect(aggregate([g, g, a, a]), Rating.again);
    });

    test('an empty list asserts', () {
      expect(() => aggregate([]), throwsA(isA<AssertionError>()));
    });
  });

  test('random answer sequences', () {
    final random = Random(230);
    for (var run = 0; run < 1000; run++) {
      final n = 1 + random.nextInt(10);
      final bundles = 1 + random.nextInt(3);
      var state = startRound(_tasks(n, bundles));
      final pRight = 0.3 + random.nextDouble() * 0.7;
      var rights = 0;
      var wordRatings = 0;
      final counted = <String, List<Rating>>{};
      while (!state.isOver) {
        expect(state.shownNumber, lessThanOrEqualTo(state.total));
        expect(rights < n, isTrue);
        final task = state.queue.first;
        final attribution = random.nextDouble() < pRight
            ? _right
            : [_wrong, _wordOnly, _grammarOnly][random.nextInt(3)];
        final (next, outcome) = _answer(state, attribution);
        if (outcome.right) rights++;
        if (outcome.wordRating != null) wordRatings++;
        final grammar = attribution.grammar;
        if (!task.isRetry && grammar != null) {
          counted.putIfAbsent(task.bundle, () => []).add(grammar);
        }
        state = next;
      }
      expect(rights, n);
      expect(wordRatings, n);
      final ratings = bundleRatings(state);
      expect(ratings.length, counted.length);
      for (final e in counted.entries) {
        expect(ratings['grammar:verbs:${e.key}'], aggregate(e.value));
      }
    }
  });
}
