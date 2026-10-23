import 'dart:math';

import 'package:fsrs/fsrs.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/attribution.dart';
import '../data/exercise_choice.dart';
import '../data/practice_data.dart';
import '../data/round.dart';
import '../data/round_plan.dart';
import '../data/selection.dart';
import '../data/topics.dart';
import '../models/course_filter.dart';
import '../models/exercise.dart';
import '../models/fsrs_card.dart';
import '../models/practice_item.dart';
import '../models/reward.dart';
import 'curriculum_provider.dart';
import 'fsrs_provider.dart';
import 'locale_provider.dart';
import 'reward_provider.dart';
import 'settings_provider.dart';

part 'round_providers.g.dart';

/// The topics the course offers now, in course order.
@riverpod
Future<List<Topic>> topics(Ref ref) async {
  final byType = await ref.watch(practicableItemsByTypeProvider.future);
  final filter = await ref.watch(courseFilterProvider.future);
  final curriculum = await ref.watch(curriculumProvider.future);
  final language = await ref.watch(dataLanguageProvider.future);
  final nouns = await getFormMetadata(
    'lib/data/latin_nouns.yaml',
    language: language,
  );
  final all = topicsOf(
    [for (final items in byType.values) ...items],
    curriculum,
    nounTypeDisplays: nouns.displayByType,
  );
  return [
    for (final topic in all)
      if (offeredBundles(
        topic,
        unlockedBundles(filter, byType[topic.dataFileId]!),
      ).isNotEmpty)
        topic,
  ];
}

/// What "Heute dran" offers; one [selectPair] call decides it.
sealed class TodayOffer {
  const TodayOffer();
}

final class MixedOffer extends TodayOffer {
  const MixedOffer();
}

/// A new topic starts blocked.
final class NewTopicOffer extends TodayOffer {
  final Topic topic;

  const NewTopicOffer(this.topic);
}

final class NothingDue extends TodayOffer {
  const NothingDue();
}

SelectionInput _selectionInput(
  Map<String, PracticeItemCard> cards,
  Map<String, List<PracticeItem>> practicable,
  CourseFilter filter,
  Scheduler scheduler,
) {
  final now = DateTime.now().toUtc();
  return (
    cards: cards,
    items: [for (final items in practicable.values) ...items],
    filter: filter,
    retrievability: (c) =>
        scheduler.getCardRetrievability(c.card, currentDateTime: now),
    now: now,
  );
}

@riverpod
Future<TodayOffer> todayOffer(Ref ref) async {
  final input = _selectionInput(
    await ref.watch(fsrsCardsProvider.future),
    await ref.watch(practicableItemsByTypeProvider.future),
    await ref.watch(courseFilterProvider.future),
    ref.watch(fsrsSchedulerProvider),
  );
  final pair = selectPair(
    cards: input.cards,
    items: input.items,
    filter: input.filter,
    retrievability: input.retrievability,
    now: input.now,
  );
  if (pair == null) return const NothingDue();
  if (!pair.anchorIsGrammar || !pair.anchorIsNew) return const MixedOffer();
  final topics = await ref.watch(topicsProvider.future);
  return NewTopicOffer(
    topics.singleWhere(
      (t) =>
          t.dataFileId == pair.word.dataFileId &&
          t.bundles.contains(pair.bundle),
    ),
  );
}

sealed class RoundRequest {
  const RoundRequest();
}

final class BlockedRound extends RoundRequest {
  final String topicId;

  const BlockedRound(this.topicId);

  @override
  bool operator ==(Object other) =>
      other is BlockedRound && other.topicId == topicId;

  @override
  int get hashCode => topicId.hashCode;
}

final class MixedRound extends RoundRequest {
  const MixedRound();

  @override
  bool operator ==(Object other) => other is MixedRound;

  @override
  int get hashCode => (MixedRound).hashCode;
}

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.
@riverpod
class Round extends _$Round {
  late Map<String, ExerciseContext> _contexts;
  late Random _rng;
  late List<ExerciseGenerator> _registry;
  final _reviewedWords = <String>{};
  bool _responding = false;

  /// Plans and builds the first tasks once. Reads its inputs with ref.read,
  /// so the word reviews during the round do not re-plan it.
  @override
  Future<RoundState> build(RoundRequest request) async {
    final cards = await ref.read(fsrsCardsProvider.future);
    final practicable = await ref.read(practicableItemsByTypeProvider.future);
    final filter = await ref.read(courseFilterProvider.future);
    final german = await ref.read(germanFormsProvider.future);
    final topics = await ref.read(topicsProvider.future);
    final avoidMacronTwins = (await ref.read(
      settingsProvider.future,
    )).avoidMacronTwins;
    final input = _selectionInput(
      cards,
      practicable,
      filter,
      ref.read(fsrsSchedulerProvider),
    );
    _rng = ref.read(exerciseRandomProvider);
    _registry = ref.read(exerciseRegistryProvider);
    _contexts = {
      for (final MapEntry(key: file, value: pool) in practicable.entries)
        file: ExerciseContext(
          unlocked: unlockedBundles(filter, pool),
          pool: pool,
          german: german,
          avoidMacronTwins: avoidMacronTwins,
        ),
    };

    final pairs = switch (request) {
      BlockedRound(:final topicId) => () {
        final topic = topics.singleWhere((t) => t.id == topicId);
        return planBlocked(
          topic,
          offeredBundles(topic, _contexts[topic.dataFileId]!.unlocked),
          input,
        );
      }(),
      MixedRound() => planMixed(input, topics),
    };
    return startRound([
      for (final (:word, :bundle) in pairs)
        RoundTask(
          word,
          bundle,
          buildExercise(
            word,
            bundle,
            _contexts[word.dataFileId]!,
            weakerStability(
              cards[PracticeItemCard.generateItemId(word)]!,
              cards[GrammarCardId(word.dataFileId, bundle)]!,
            ),
            _rng,
            registry: _registry,
          ),
        ),
    ]);
  }

  /// A retry asks the recognition class and avoids the failed kind.
  Exercise _retry(RoundTask failed) => buildExercise(
    failed.word,
    failed.bundle,
    _contexts[failed.word.dataFileId]!,
    0,
    _rng,
    registry: _registry,
    avoid: {failed.exercise.kind},
  );

  /// Reviews the word card on its first attempt in the round, feeds the
  /// rewards, advances. At the end: reviews the bundles (one save), sends
  /// [RoundFinished]. A response while one is in flight is ignored.
  Future<void> respond(ExerciseResponse response) async {
    if (_responding) return;
    _responding = true;
    try {
      await _respond(response);
    } finally {
      _responding = false;
    }
  }

  Future<void> _respond(ExerciseResponse response) async {
    final current = state.requireValue;
    final task = current.queue.first;
    final (next, outcome) = answer(
      current,
      attribute(task.word, task.exercise, response),
      _retry,
    );
    final scheduler = ref.read(fsrsSchedulerProvider);
    final wordRating = outcome.wordRating;
    if (wordRating != null && _reviewedWords.add(task.exercise.wordCardId)) {
      await reviewWordCard(
        scheduler,
        await ref.read(fsrsCardsProvider.future),
        task.exercise.wordCardId,
        wordRating,
      );
      ref.invalidate(fsrsCardsProvider);
    }
    final rewards = ref.read(rewardsProvider.notifier);
    await rewards.send(
      Answered(
        right: outcome.right,
        firstAttempt: outcome.firstAttempt,
        at: DateTime.now(),
      ),
    );
    if (next.isOver) {
      await reviewGrammarCards(
        scheduler,
        await ref.read(fsrsCardsProvider.future),
        bundleRatings(next),
      );
      ref.invalidate(fsrsCardsProvider);
      await rewards.send(const RoundFinished());
    }
    state = AsyncData(next);
  }
}
