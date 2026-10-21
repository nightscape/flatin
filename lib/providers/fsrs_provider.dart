import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart';
import '../data/asset_text.dart';
import '../data/attribution.dart';
import '../data/exercise_choice.dart';
import '../data/german_forms.dart';
import '../data/selection.dart';
import '../models/distractor_strategy.dart';
import '../models/exercise.dart';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';
import '../services/fsrs_storage.dart';
import '../data/practice_data.dart';
import 'curriculum_provider.dart';
import 'locale_provider.dart';
import 'settings_provider.dart';

part 'fsrs_provider.g.dart';

/// FSRS Scheduler instance provider
@riverpod
Scheduler fsrsScheduler(Ref ref) {
  return Scheduler();
}

/// Every word card and grammar card, synced with the YAML items.
@riverpod
Future<Map<String, PracticeItemCard>> fsrsCards(Ref ref) async {
  final items = await loadAllPracticeItems();
  await FsrsStorage.syncCards(items);
  return FsrsStorage.syncGrammarCards(items);
}

/// The due word cards; grammar cards are due through [nextGrammarExercise].
@riverpod
Future<List<PracticeItemCard>> dueCards(Ref ref) async {
  final cards = await ref.watch(fsrsCardsProvider.future);
  final now = DateTime.now().toUtc();

  return cards.values
      .where((card) => !card.itemId.startsWith('grammar:'))
      .where((card) => card.due.isBefore(now) || card.due.isAtSameMomentAs(now))
      .toList()
    ..sort((a, b) => a.due.compareTo(b.due));
}

/// Every item the user can practise, by exercise type.
///
/// The one place the course filter is applied, so that no consumer can route
/// around it. An item whose forms are all untaught or switched off has
/// nothing to ask and is left out.
@riverpod
Future<Map<String, List<PracticeItem>>> practicableItemsByType(Ref ref) async {
  final filter = await ref.watch(courseFilterProvider.future);

  final itemsByType = <String, List<PracticeItem>>{'nouns': [], 'verbs': []};
  final language = await ref.watch(dataLanguageProvider.future);
  for (final item in await loadAllPracticeItems(language: language)) {
    if (!filter.reachesPractice(item)) continue;
    itemsByType[item.dataFileId]!.add(item);
  }

  return itemsByType;
}

/// Provider for due items by exercise type
@riverpod
Future<Map<String, List<PracticeItem>>> dueItemsByType(Ref ref) async {
  final dueCardsList = await ref.watch(dueCardsProvider.future);
  final practicable = await ref.watch(practicableItemsByTypeProvider.future);

  final itemsById = <String, PracticeItem>{};
  for (final items in practicable.values) {
    for (final item in items) {
      itemsById[PracticeItemCard.generateItemId(item)] = item;
    }
  }

  final dueItemsByType = <String, List<PracticeItem>>{'nouns': [], 'verbs': []};
  for (final card in dueCardsList) {
    // Cards exist for items the current selection filters out, too.
    final item = itemsById[card.itemId];
    if (item == null) continue;
    dueItemsByType[item.dataFileId]!.add(item);
  }

  return dueItemsByType;
}

/// Get next due item for a specific exercise type
@riverpod
Future<PracticeItem?> nextDueItem(Ref ref, String dataFileId) async {
  final dueItemsByType = await ref.watch(dueItemsByTypeProvider.future);
  final items = dueItemsByType[dataFileId] ?? [];
  return items.isNotEmpty ? items.first : null;
}

/// Review a card with a rating; the grammar cards of [grammar] are reviewed
/// with theirs, in the same save. A grammar card that does not exist throws.
Future<void> reviewCard(
  WidgetRef ref,
  PracticeItem item,
  Rating rating, [
  Map<GrammarBundle, Rating> grammar = const {},
]) async {
  final scheduler = ref.read(fsrsSchedulerProvider);
  final cardsAsync = await ref.read(fsrsCardsProvider.future);
  final cards = Map<String, PracticeItemCard>.from(cardsAsync);
  final itemId = PracticeItemCard.generateItemId(item);

  final cardWrapper = cards[itemId];
  if (cardWrapper == null) {
    // Card doesn't exist, create it
    final newCard = PracticeItemCard.createNew(item);
    cards[itemId] = newCard;
  }

  cards[itemId] = _reviewed(scheduler, cards[itemId]!, rating);
  for (final MapEntry(key: bundle, value: r) in grammar.entries) {
    final id = GrammarCardId(item.dataFileId, bundle);
    cards[id] = _reviewed(
      scheduler,
      cards[id] ?? (throw StateError('no card "$id"')),
      r,
    );
  }
  await FsrsStorage.saveCards(cards);

  // Invalidate providers to refresh UI
  ref.invalidate(fsrsCardsProvider);
}

PracticeItemCard _reviewed(
  Scheduler scheduler,
  PracticeItemCard wrapper,
  Rating rating,
) {
  final (:card, :reviewLog) = scheduler.reviewCard(wrapper.card, rating);
  return wrapper.copyWith(
    card: card,
    lastReview: reviewLog.reviewDateTime,
    due: card.due,
  );
}

/// The German texts of the Latin verbs and nouns; none for a UI language
/// other than German, so the kinds that show them are not built.
@riverpod
Future<GermanForms> germanForms(Ref ref) async =>
    await ref.watch(dataLanguageProvider.future) == 'de'
    ? GrammarGermanForms(
        await loadAssetText('lib/data/german_verbs.yaml'),
        await loadGrammarFile('verbs'),
        nouns: (
          yaml: await loadAssetText('lib/data/german_nouns.yaml'),
          latin: await loadGrammarFile('nouns'),
        ),
      )
    : const NoForms();

/// The randomness of the grammar exercises; a test overrides it with a seed.
@riverpod
Random exerciseRandom(Ref ref) => Random();

typedef GrammarExercise = ({PracticeItem word, Exercise exercise});

/// The generators that build the grammar exercises; a test overrides it.
@riverpod
List<ExerciseGenerator> exerciseRegistry(Ref ref) => exerciseGenerators;

/// The word and bundle [selectPair] picks; null when no card is due. Builds
/// no exercise, so it is cheap enough to watch from the home screen.
@riverpod
Future<SelectedPair?> nextGrammarPair(Ref ref) async {
  final cards = await ref.watch(fsrsCardsProvider.future);
  final filter = await ref.watch(courseFilterProvider.future);
  final practicable = await ref.watch(practicableItemsByTypeProvider.future);
  final scheduler = ref.watch(fsrsSchedulerProvider);
  final now = DateTime.now().toUtc();
  return selectPair(
    cards: cards,
    items: [for (final items in practicable.values) ...items],
    filter: filter,
    retrievability: (c) =>
        scheduler.getCardRetrievability(c.card, currentDateTime: now),
    now: now,
  );
}

/// The next grammar exercise: the pair of [nextGrammarPair], asked in a kind
/// that fits the stability of its weaker card. Null when no card is due.
@riverpod
Future<GrammarExercise?> nextGrammarExercise(Ref ref) async {
  final pair = await ref.watch(nextGrammarPairProvider.future);
  if (pair == null) return null;
  final cards = await ref.watch(fsrsCardsProvider.future);
  final filter = await ref.watch(courseFilterProvider.future);
  final practicable = await ref.watch(practicableItemsByTypeProvider.future);
  final german = await ref.watch(germanFormsProvider.future);
  final pool = practicable[pair.word.dataFileId]!;
  final exercise = buildExercise(
    pair.word,
    pair.bundle,
    ExerciseContext(
      unlocked: unlockedBundles(filter, pool),
      pool: pool,
      german: german,
    ),
    weakerStability(
      cards[PracticeItemCard.generateItemId(pair.word)]!,
      cards[pair.grammarCardId]!,
    ),
    ref.watch(exerciseRandomProvider),
    registry: ref.watch(exerciseRegistryProvider),
  );
  return (word: pair.word, exercise: exercise);
}

/// Reviews the word card and the grammar card of [exercise] with the ratings
/// [attribute] gives [response], and stores both; a grammar card the response
/// says nothing about stays as it is.
Future<Map<String, PracticeItemCard>> reviewExerciseCards(
  Scheduler scheduler,
  Map<String, PracticeItemCard> stored,
  GrammarExercise asked,
  ExerciseResponse response,
) async {
  final (:word, :exercise) = asked;
  final rating = attribute(word, exercise, response);
  final cards = Map<String, PracticeItemCard>.from(stored);
  final ratings = {
    exercise.wordCardId: rating.word,
    if (rating.grammar != null) exercise.grammarCardId: rating.grammar!,
  };
  for (final MapEntry(key: id, value: r) in ratings.entries) {
    cards[id] = _reviewed(
      scheduler,
      cards[id] ?? (throw StateError('no card "$id"')),
      r,
    );
  }
  await FsrsStorage.saveCards(cards);
  return cards;
}

/// [reviewExerciseCards], then the next exercise follows from the new cards.
Future<void> reviewExercise(
  WidgetRef ref,
  GrammarExercise asked,
  ExerciseResponse response,
) async {
  await reviewExerciseCards(
    ref.read(fsrsSchedulerProvider),
    await ref.read(fsrsCardsProvider.future),
    asked,
    response,
  );
  ref.invalidate(fsrsCardsProvider);
}

/// Reviews the card and tells the learner when the progress could not be
/// stored. Returns false in that case, so the caller keeps the item open.
Future<bool> reviewCardReportingErrors(
  BuildContext context,
  WidgetRef ref,
  PracticeItem item,
  Rating rating, [
  Map<GrammarBundle, Rating> grammar = const {},
]) async {
  try {
    await reviewCard(ref, item, rating, grammar);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FlutterI18n.translate(
              context,
              'practice.saveError',
              translationParams: {'error': e.toString()},
            ),
          ),
        ),
      );
    }
    return false;
  }
}

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.
@riverpod
Future<List<String>> translationChoices(Ref ref, PracticeItem item) async {
  final yamlPath = 'lib/data/latin_${item.dataFileId}.yaml';
  final allItems = await loadPracticeItems(
    yamlPath,
    language: item.derivation.grammar.language,
  );

  final strategy = distractorStrategyById(
    (await ref.watch(settingsProvider.future)).distractorStrategyId,
  );
  final seed = item.translation.hashCode;
  final choices = [
    item.translation,
    ...strategy.pick(item, allItems, 3, Random(seed)),
  ];
  choices.shuffle(Random(seed + 1));
  return choices;
}

/// Get retrievability for a card
Future<double?> getCardRetrievability(WidgetRef ref, PracticeItem item) async {
  final scheduler = ref.read(fsrsSchedulerProvider);
  final cardsAsync = await ref.read(fsrsCardsProvider.future);
  final cards = cardsAsync;

  final itemId = PracticeItemCard.generateItemId(item);
  final cardWrapper = cards[itemId];

  if (cardWrapper == null) {
    return null;
  }

  try {
    return scheduler.getCardRetrievability(cardWrapper.card);
  } catch (e) {
    return null;
  }
}
