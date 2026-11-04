import 'dart:math';

import 'package:fsrs/fsrs.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/attribution.dart';
import '../data/exercise_choice.dart';
import '../data/exercise_interpreter.dart' show SpecGenerator;
import '../data/exercise_spec.dart' show OneSentence;
import '../data/practice_data.dart';
import '../data/round.dart';
import '../data/round_plan.dart';
import '../data/selection.dart';
import '../data/sentences.dart';
import '../data/topics.dart';
import '../data/word_focus.dart';
import '../models/course.dart';
import '../models/course_filter.dart';
import '../models/exercise.dart';
import '../models/fsrs_card.dart';
import '../models/practice_item.dart';
import '../models/reward.dart';
import 'course_provider.dart';
import 'curriculum_provider.dart';
import 'fsrs_provider.dart';
import 'locale_provider.dart';
import 'reward_provider.dart';
import 'settings_provider.dart';

part 'round_providers.g.dart';

/// The sentences of the sentence kinds; an asset, so loaded once.
@Riverpod(keepAlive: true)
Future<SentenceCorpus> sentenceCorpus(Ref ref) => loadSentenceCorpus();

/// The topics the course offers now with words of [focus], in course order.
@riverpod
Future<List<Topic>> topics(Ref ref, WordFocus focus) async {
  final byType = await ref.watch(practicableItemsByTypeProvider.future);
  final focused = focus.narrow(byType);
  final filter = await ref.watch(courseFilterProvider.future);
  final curriculum = await ref.watch(curriculumProvider.future);
  final language = await ref.watch(dataLanguageProvider.future);
  final course = await ref.watch(courseProvider.future);
  final nouns = await getFormMetadata(
    course.ofRole(DataFileRole.noun).path,
    language: language,
  );
  final all = topicsOf(
    [for (final items in byType.values) ...items],
    curriculum,
    nounTypeDisplays: nouns.displayByType,
  );
  final unlocked = {
    for (final MapEntry(:key, :value) in focused.entries)
      key: unlockedBundles(filter, value),
  };
  return [
    for (final topic in all)
      if (offeredBundles(topic, unlocked[topic.dataFileId]!).isNotEmpty) topic,
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

/// Nothing is due; a mixed round still starts, with the cards of lowest R.
final class NothingDue extends TodayOffer {
  const NothingDue();
}

/// No word of the focus reaches practice, so no round can start.
final class NothingToPractise extends TodayOffer {
  const NothingToPractise();
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
Future<TodayOffer> todayOffer(Ref ref, WordFocus focus) async {
  final input = _selectionInput(
    await ref.watch(fsrsCardsProvider.future),
    focus.narrow(await ref.watch(practicableItemsByTypeProvider.future)),
    await ref.watch(courseFilterProvider.future),
    ref.watch(fsrsSchedulerProvider),
  );
  final index = BundleIndex(input.items, input.filter);
  SelectedPair? select({required bool includeNotDue}) => selectPair(
    index: index,
    cards: input.cards,
    items: input.items,
    filter: input.filter,
    retrievability: input.retrievability,
    now: input.now,
    includeNotDue: includeNotDue,
  );
  final pair = select(includeNotDue: false);
  if (pair == null) {
    return select(includeNotDue: true) == null
        ? const NothingToPractise()
        : const NothingDue();
  }
  if (!pair.anchorIsGrammar || !pair.anchorIsNew || pair.word.isVocab) {
    return const MixedOffer();
  }
  final topics = await ref.watch(topicsProvider(focus).future);
  return NewTopicOffer(
    topics.singleWhere(
      (t) =>
          t.dataFileId == pair.word.dataFileId &&
          t.bundles.contains(pair.bundle),
    ),
  );
}

sealed class RoundRequest {
  /// The round asks only words of this focus, within the course range.
  final WordFocus focus;

  const RoundRequest(this.focus);
}

final class BlockedRound extends RoundRequest {
  final String topicId;

  const BlockedRound(this.topicId, [super.focus = const AllWords()]);

  @override
  bool operator ==(Object other) =>
      other is BlockedRound && other.topicId == topicId && other.focus == focus;

  @override
  int get hashCode => Object.hash(topicId, focus);
}

final class MixedRound extends RoundRequest {
  const MixedRound([super.focus = const AllWords()]);

  @override
  bool operator ==(Object other) => other is MixedRound && other.focus == focus;

  @override
  int get hashCode => Object.hash(MixedRound, focus);
}

/// Asks [inner] in [ctx], whatever context the caller passes.
final class _InContext implements ExerciseGenerator {
  const _InContext(this.inner, this.ctx);

  final ExerciseGenerator inner;
  final ExerciseContext ctx;

  @override
  ExerciseKind get kind => inner.kind;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext _,
    Random rng,
  ) => inner.build(word, bundle, ctx, rng);
}

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.
@riverpod
class Round extends _$Round {
  /// Per data file; a sentence kind gets the context over all files instead,
  /// as its sentences mix the files.
  late Map<String, ExerciseContext> _contexts;
  late Random _rng;
  late List<ExerciseGenerator> _registry;
  final _reviewedWords = <String>{};
  final _difficultyBefore = <String, double?>{};
  bool _responding = false;

  /// Plans and builds the first tasks once. Reads its inputs with ref.read,
  /// so the word reviews during the round do not re-plan it.
  @override
  Future<RoundState> build(RoundRequest request) async {
    final cards = await ref.read(fsrsCardsProvider.future);
    final practicable = await ref.read(practicableItemsByTypeProvider.future);
    final filter = await ref.read(courseFilterProvider.future);
    final german = await ref.read(germanFormsProvider.future);
    final topics = await ref.read(topicsProvider(request.focus).future);
    final settings = await ref.read(settingsProvider.future);
    final corpus = await ref.read(sentenceCorpusProvider.future);
    final focused = request.focus.narrow(practicable);
    final input = _selectionInput(
      cards,
      focused,
      filter,
      ref.read(fsrsSchedulerProvider),
    );
    ExerciseContext contextOf(
      List<PracticeItem> pool, {
      SentenceCorpus? sentences,
      int? reached,
    }) => ExerciseContext(
      unlocked: unlockedBundles(filter, pool),
      pool: pool,
      german: german,
      avoidMacronTwins: settings.avoidMacronTwins,
      formPracticed: (word, label) =>
          filter.formPracticed(word.dataFileId, label),
      stabilityOf: (cardId) => cards[cardId]?.card.stability,
      sentences: sentences,
      reachedLesson: reached,
    );
    _rng = ref.read(exerciseRandomProvider);
    _contexts = {
      for (final MapEntry(key: file, value: pool) in practicable.entries)
        file: contextOf(pool),
    };
    final acrossFiles = contextOf(
      [for (final pool in practicable.values) ...pool],
      sentences: corpus,
      reached: reachedLesson(filter.settings),
    );
    _registry = [
      for (final g in ref.read(exerciseRegistryProvider))
        g is SpecGenerator && g.spec.select is OneSentence
            ? _InContext(g, acrossFiles)
            : g,
    ];

    final pairs = switch (request) {
      BlockedRound(:final topicId) => () {
        final topic = topics.singleWhere((t) => t.id == topicId);
        return planBlocked(
          topic,
          offeredBundles(
            topic,
            unlockedBundles(filter, focused[topic.dataFileId]!),
          ),
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
    final wordCardId = task.exercise.wordCardId;
    final cards = await ref.read(fsrsCardsProvider.future);
    final wordDifficulty = _difficultyBefore.putIfAbsent(
      wordCardId,
      () => cards[wordCardId]?.card.difficulty,
    );
    if (wordRating != null && _reviewedWords.add(wordCardId)) {
      await reviewWordCard(scheduler, cards, wordCardId, wordRating);
      ref.invalidate(fsrsCardsProvider);
    }
    final rewards = ref.read(rewardsProvider.notifier);
    await rewards.send(
      Answered(
        right: outcome.right,
        firstAttempt: outcome.firstAttempt,
        wordDifficulty: wordDifficulty,
        kind: task.exercise.kind.name,
        dataFile: task.word.dataFileId,
        partial: outcome.right ? 0 : partialOf(task.exercise.answer, response),
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
