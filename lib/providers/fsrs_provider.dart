import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';
import '../services/fsrs_storage.dart';
import '../data/practice_data.dart';

part 'fsrs_provider.g.dart';

/// FSRS Scheduler instance provider
@riverpod
Scheduler fsrsScheduler(Ref ref) {
  return Scheduler();
}

/// Provider for all FSRS cards (synced with YAML items)
@riverpod
Future<Map<String, PracticeItemCard>> fsrsCards(Ref ref) async {
  // Load all practice items from YAML files
  final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
  final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  final allItems = [...nouns, ...verbs];

  // Sync cards with current items (creates new cards for new items)
  return await FsrsStorage.syncCards(allItems);
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

/// Provider for due items by exercise type
@riverpod
Future<Map<String, List<PracticeItem>>> dueItemsByType(Ref ref) async {
  final dueCardsList = await ref.watch(dueCardsProvider.future);

  // Load all items
  final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
  final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  final allItems = [...nouns, ...verbs];

  // Create a map of itemId -> PracticeItem
  final itemsById = <String, PracticeItem>{};
  for (final item in allItems) {
    final itemId = PracticeItemCard.generateItemId(item);
    itemsById[itemId] = item;
  }

  // Group due items by dataFileId
  final dueItemsByType = <String, List<PracticeItem>>{'nouns': [], 'verbs': []};

  for (final card in dueCardsList) {
    final item = itemsById[card.itemId];
    if (item != null) {
      final type = item.dataFileId;
      final typeList = dueItemsByType[type];
      if (typeList != null) {
        typeList.add(item);
      }
    }
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
