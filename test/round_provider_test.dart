import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/round.dart';
import 'package:latin_practice/data/round_plan.dart' show roundLength;
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/services/fsrs_storage.dart';

import 'support/course_providers.dart';
import 'support/grammar_exercise_harness.dart';

ProviderContainer _container() => ProviderContainer(
  retry: noRetry,
  overrides: [
    dataLanguageProvider.overrideWith((ref) => 'de'),
    exerciseRandomProvider.overrideWithValue(Random(17)),
  ],
);

String _fingerprint(PracticeItemCard c) =>
    '${c.lastReview}|${c.card.stability}|${c.card.state}';

/// Runs [request] to its end; [wrong] says which answers are wrong, counted
/// over every answer including retries. Returns how often each card changed
/// in storage, per answer, and the first-attempt attributions.
Future<
  ({
    List<Set<String>> changedPerAnswer,
    Map<String, PracticeItemCard> before,
    Map<String, PracticeItemCard> after,
    List<(RoundTask, Attribution)> firsts,
    int points,
    int buildings,
  })
>
_run(ProviderContainer c, RoundRequest request, Set<int> wrong) async {
  final provider = roundProvider(request);
  c.listen(provider, (_, _) {});
  final before = await FsrsStorage.loadCards();
  var state = await c.read(provider.future);
  final changedPerAnswer = <Set<String>>[];
  final firsts = <(RoundTask, Attribution)>[];
  var last = before;
  for (var n = 0; !state.isOver; n++) {
    expect(n, lessThan(40), reason: 'the round does not end');
    final task = state.queue.first;
    final (right, wrongResponse) = rightAndWrong(task.word, task.exercise);
    final response = wrong.contains(n) ? wrongResponse : right;
    if (!task.isRetry) {
      firsts.add((task, attribute(task.word, task.exercise, response)));
    }
    await c.read(provider.notifier).respond(response);
    await c.pump();
    state = await c.read(provider.future);
    expect(state.answeredFirst, firsts.length, reason: 'the round re-planned');
    final now = await FsrsStorage.loadCards();
    changedPerAnswer.add({
      for (final id in now.keys)
        if (_fingerprint(now[id]!) != _fingerprint(last[id]!)) id,
    });
    last = now;
  }
  final ledger = await c.read(rewardsProvider.future);
  return (
    changedPerAnswer: changedPerAnswer,
    before: before,
    after: last,
    firsts: firsts,
    points: ledger.earnedOf(coins),
    buildings: ledger.buildings.length,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh store at lesson 1 offers a new topic of lesson 1', () async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    final c = _container();
    addTearDown(c.dispose);
    final offer = await c.read(todayOfferProvider.future);
    expect(offer, isA<NewTopicOffer>());
    expect((offer as NewTopicOffer).topic.lesson, 1);
  });

  test('round requests compare by value', () {
    expect(BlockedRound('verbs:1'), const BlockedRound('verbs:1'));
    expect(BlockedRound('verbs:1').hashCode, 'verbs:1'.hashCode);
    expect(BlockedRound('verbs:1'), isNot(const BlockedRound('nouns:1')));
    expect(MixedRound(), const MixedRound());
  });

  for (final (name, wrong) in [
    ('all right', <int>{}),
    ('one wrong', {0}),
  ]) {
    test('a blocked round with $name reviews each word once on its first '
        'attempt and every bundle once, at the end, in one save', () async {
      seedSettings(Settings(courseWords: LessonRange(1, 1)));
      final c = _container();
      addTearDown(c.dispose);
      final offer = await c.read(todayOfferProvider.future) as NewTopicOffer;
      final scheduler = c.read(fsrsSchedulerProvider);

      final run = await _run(c, BlockedRound(offer.topic.id), wrong);

      expect(run.firsts, hasLength(roundLength));
      expect(
        run.firsts.map((f) => f.$1.word).toSet().length,
        lessThan(roundLength),
        reason: 'a word repeats, so a second review would show',
      );
      expect(run.changedPerAnswer, hasLength(roundLength + wrong.length));
      final grammarIds = {
        for (final (task, _) in run.firsts)
          GrammarCardId(task.word.dataFileId, task.bundle),
      };
      for (final (i, changed) in run.changedPerAnswer.indexed) {
        final isLast = i == run.changedPerAnswer.length - 1;
        expect(
          changed.where((id) => id.startsWith('grammar:')).toSet(),
          isLast ? grammarIds : isEmpty,
          reason: 'answer $i',
        );
      }

      final firstRatingOf = <String, Rating>{};
      final grammarFirst = <String, List<Rating>>{};
      for (final (task, attribution) in run.firsts) {
        firstRatingOf.putIfAbsent(
          task.exercise.wordCardId,
          () => attribution.word,
        );
        final g = attribution.grammar;
        if (g != null) {
          grammarFirst
              .putIfAbsent(
                GrammarCardId(task.word.dataFileId, task.bundle),
                () => [],
              )
              .add(g);
        }
      }
      final wordChanges = [
        for (final changed in run.changedPerAnswer)
          ...changed.where((id) => !id.startsWith('grammar:')),
      ];
      expect(wordChanges.toSet(), firstRatingOf.keys.toSet());
      expect(wordChanges, hasLength(firstRatingOf.length));

      final expected = {
        ...firstRatingOf,
        for (final e in grammarFirst.entries) e.key: aggregate(e.value),
      };
      expect(grammarFirst.keys.toSet(), grammarIds);
      for (final MapEntry(key: id, value: rating) in expected.entries) {
        final once = scheduler.reviewCard(run.before[id]!.card, rating).card;
        expect(run.after[id]!.card.stability, once.stability, reason: id);
        expect(run.after[id]!.card.state, once.state, reason: id);
      }
      expect(run.points, 10 * (roundLength - wrong.length) + 5 * wrong.length);
      expect(run.buildings, 0);
    });
  }

  test('the bonus reads the word difficulty from before the review', () async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    final c = _container();
    addTearDown(c.dispose);
    final offer = await c.read(todayOfferProvider.future) as NewTopicOffer;
    final provider = roundProvider(BlockedRound(offer.topic.id));
    c.listen(provider, (_, _) {});
    final task = (await c.read(provider.future)).queue.first;
    final wordId = task.exercise.wordCardId;
    final right = rightAndWrong(task.word, task.exercise).$1;
    final rating = attribute(task.word, task.exercise, right).word;

    final cards = await FsrsStorage.loadCards();
    final reviewed = c
        .read(fsrsSchedulerProvider)
        .reviewCard(cards[wordId]!.card, Rating.good)
        .card;
    final hard = reviewed.copyWith(difficulty: 7.01);
    final after = c.read(fsrsSchedulerProvider).reviewCard(hard, rating).card;
    expect(after.difficulty, lessThan(7), reason: 'the review crosses 7');
    cards[wordId] = cards[wordId]!.copyWith(card: hard);
    await FsrsStorage.saveCards(cards);
    c.invalidate(fsrsCardsProvider);

    await c.read(provider.notifier).respond(right);

    final ledger = await c.read(rewardsProvider.future);
    expect(ledger.taggedOf(coins, 'bonus'), 10);
    expect(ledger.earnedOf(coins), 20);
  });

  test('a second response while one is in flight is ignored', () async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    final sent = <RewardEvent>[];
    final c = ProviderContainer(
      retry: noRetry,
      overrides: [
        dataLanguageProvider.overrideWith((ref) => 'de'),
        exerciseRandomProvider.overrideWithValue(Random(17)),
        rewardsProvider.overrideWith(() => _RecordingRewards(sent)),
      ],
    );
    addTearDown(c.dispose);
    final offer = await c.read(todayOfferProvider.future) as NewTopicOffer;
    final provider = roundProvider(BlockedRound(offer.topic.id));
    c.listen(provider, (_, _) {});
    final task = (await c.read(provider.future)).queue.first;
    final wordId = task.exercise.wordCardId;
    final before = await FsrsStorage.loadCards();
    final right = rightAndWrong(task.word, task.exercise).$1;

    final first = c.read(provider.notifier).respond(right);
    final second = c.read(provider.notifier).respond(right);
    await Future.wait([first, second]);

    expect(c.read(provider).requireValue.answeredFirst, 1);
    expect(sent, [isA<Answered>()]);
    final stored = await FsrsStorage.loadCards();
    expect(
      {
        for (final id in stored.keys)
          if (_fingerprint(stored[id]!) != _fingerprint(before[id]!)) id,
      },
      {wordId},
    );
    final once = c
        .read(fsrsSchedulerProvider)
        .reviewCard(
          before[wordId]!.card,
          attribute(task.word, task.exercise, right).word,
        )
        .card;
    expect(stored[wordId]!.card.stability, once.stability);
  });

  test(
    'an aborted round keeps its word reviews and reviews no bundle',
    () async {
      seedSettings(Settings(courseWords: LessonRange(1, 1)));
      final c = _container();
      addTearDown(c.dispose);
      final offer = await c.read(todayOfferProvider.future) as NewTopicOffer;
      final provider = roundProvider(BlockedRound(offer.topic.id));
      final sub = c.listen(provider, (_, _) {});
      await c.read(provider.future);
      final before = await FsrsStorage.loadCards();
      final asked = <String>{};
      for (var n = 0; n < 3; n++) {
        final task = c.read(provider).requireValue.queue.first;
        asked.add(task.exercise.wordCardId);
        await c
            .read(provider.notifier)
            .respond(rightAndWrong(task.word, task.exercise).$1);
      }
      sub.close();
      await Future<void>.delayed(Duration.zero);
      expect(c.exists(provider), isFalse);

      final stored = await FsrsStorage.loadCards();
      final changed = {
        for (final id in stored.keys)
          if (_fingerprint(stored[id]!) != _fingerprint(before[id]!)) id,
      };
      expect(changed, asked);
      expect(changed.where((id) => id.startsWith('grammar:')), isEmpty);
    },
  );
}

final class _RecordingRewards extends Rewards {
  _RecordingRewards(this.sent);

  final List<RewardEvent> sent;

  @override
  Future<List<RewardEffect>> send(RewardEvent event) {
    sent.add(event);
    return super.send(event);
  }
}
