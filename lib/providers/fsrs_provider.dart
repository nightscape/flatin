import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';
import '../services/fsrs_storage.dart';
import '../data/practice_data.dart';
import 'lesson_provider.dart';
import 'settings_provider.dart';

part 'fsrs_provider.g.dart';

/// FSRS Scheduler instance provider
@riverpod
Scheduler fsrsScheduler(Ref ref) {
  return Scheduler();
}

/// Provider for all FSRS cards (synced with YAML items)
@riverpod
Future<Map<String, PracticeItemCard>> fsrsCards(Ref ref) async {
  // Sync cards with current items (creates new cards for new items)
  return await FsrsStorage.syncCards(await loadAllPracticeItems());
}

/// Provider for due cards
@riverpod
Future<List<PracticeItemCard>> dueCards(Ref ref) async {
  final cards = await ref.watch(fsrsCardsProvider.future);
  final now = DateTime.now().toUtc();

  return cards.values
      .where((card) => card.due.isBefore(now) || card.due.isAtSameMomentAs(now))
      .toList()
    ..sort((a, b) => a.due.compareTo(b.due));
}

/// Every item the user can practise, by exercise type.
///
/// The one place the word and type selections are applied, so that no consumer
/// can route around them.
@riverpod
Future<Map<String, List<PracticeItem>>> practicableItemsByType(Ref ref) async {
  final lessonData = await ref.watch(lessonDataProvider.future);
  final settings = await ref.watch(settingsProvider.future);

  final itemsByType = <String, List<PracticeItem>>{'nouns': [], 'verbs': []};
  for (final item in await loadAllPracticeItems()) {
    if (!lessonData.includes(item, settings.deselectedWords)) continue;
    if (!settings.isTypeEnabled(item.dataFileId, item.type)) continue;
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

/// Review a card with a rating
Future<void> reviewCard(WidgetRef ref, PracticeItem item, Rating rating) async {
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

  final cardWrapperToReview = cards[itemId]!;

  // Review the card with FSRS
  final (:card, :reviewLog) = scheduler.reviewCard(
    cardWrapperToReview.card,
    rating,
  );

  // Update the card wrapper with new card state and due date
  final updatedCard = cardWrapperToReview.copyWith(
    card: card,
    lastReview: reviewLog.reviewDateTime,
    due: card.due,
  );

  // Save updated card
  cards[itemId] = updatedCard;
  await FsrsStorage.saveCards(cards);

  // Invalidate providers to refresh UI
  ref.invalidate(fsrsCardsProvider);
}

/// Reviews the card and tells the learner when the progress could not be
/// stored. Returns false in that case, so the caller keeps the item open.
Future<bool> reviewCardReportingErrors(
  BuildContext context,
  WidgetRef ref,
  PracticeItem item,
  Rating rating,
) async {
  try {
    await reviewCard(ref, item, rating);
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
/// the correct translation plus 3 random distractors from the same data file.
@riverpod
Future<List<String>> translationChoices(Ref ref, PracticeItem item) async {
  final yamlPath = 'lib/data/latin_${item.dataFileId}.yaml';
  final allItems = await loadPracticeItems(yamlPath);

  final seed = item.translation.hashCode;
  final otherTranslations = allItems
      .where((i) => i.translation != item.translation)
      .map((i) => i.translation)
      .toSet()
      .toList()
    ..shuffle(Random(seed));

  final choices = [item.translation, ...otherTranslations.take(3)];
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
