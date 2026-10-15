import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';
import 'fsrs_legacy_ids.dart';

class FsrsStorage {
  static const String _storageKey = 'fsrs_cards';
  static const String _currentVersion = '2.0';

  /// Load all FSRS cards from storage, converting pre-2.0 ids on the way.
  ///
  /// [currentItems] is what the stored content hashes are resolved against, so
  /// the conversion must happen before [syncCards] fills in missing cards.
  ///
  /// A read, parse or conversion error throws: an empty map would make
  /// [syncCards] overwrite the learner's whole review history with new cards.
  static Future<Map<String, PracticeItemCard>> loadCards(
    List<PracticeItem> currentItems,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cardsJson = prefs.getString(_storageKey);

    if (cardsJson == null) {
      return {};
    }

    final json = jsonDecode(cardsJson) as Map<String, dynamic>;
    final version = json['version'] as String? ?? '0.0';

    final cardsList = json['cards'] as List<dynamic>;
    final cardsMap = <String, PracticeItemCard>{};

    for (final cardData in cardsList) {
      final card = PracticeItemCard.fromMap(cardData as Map<String, dynamic>);
      cardsMap[card.itemId] = card;
    }

    if (version == _currentVersion) {
      return cardsMap;
    }

    final converted = _convertLegacyIds(cardsMap, currentItems);
    await saveCards(converted);
    return converted;
  }

  /// Re-keys cards stored under the pre-2.0 content hash to the item id.
  ///
  /// Where several old cards land on one item, the one reviewed last wins;
  /// a hash that matches no current item keeps its key and is ignored as today.
  static Map<String, PracticeItemCard> _convertLegacyIds(
    Map<String, PracticeItemCard> storedCards,
    List<PracticeItem> currentItems,
  ) {
    final itemIdByLegacyId = Map<String, String>.from(deletedDuplicateIds);
    for (final item in currentItems) {
      itemIdByLegacyId[PracticeItemCard.legacyHashId(item)] =
          PracticeItemCard.generateItemId(item);
    }

    final converted = <String, PracticeItemCard>{};
    for (final entry in storedCards.entries) {
      final itemId = itemIdByLegacyId[entry.key];
      if (itemId == null) {
        converted[entry.key] = entry.value;
        continue;
      }
      converted[itemId] = _lastReviewed(
        converted[itemId],
        entry.value,
      ).copyWith(itemId: itemId);
    }
    return converted;
  }

  static PracticeItemCard _lastReviewed(
    PracticeItemCard? kept,
    PracticeItemCard candidate,
  ) {
    if (kept == null || kept.lastReview == null) return candidate;
    if (candidate.lastReview == null) return kept;
    return candidate.lastReview!.isAfter(kept.lastReview!) ? candidate : kept;
  }

  /// Save all FSRS cards to storage
  static Future<void> saveCards(Map<String, PracticeItemCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final cardsList = cards.values.map((card) => card.toMap()).toList();

    final json = {'version': _currentVersion, 'cards': cardsList};

    final cardsJson = jsonEncode(json);
    await prefs.setString(_storageKey, cardsJson);
  }

  /// Sync cards with current YAML items - creates new cards for new items
  static Future<Map<String, PracticeItemCard>> syncCards(
    List<PracticeItem> currentItems,
  ) async {
    PracticeItemCard.assertUniqueItemIds(currentItems);

    final storedCards = await loadCards(currentItems);
    final syncedCards = Map<String, PracticeItemCard>.from(storedCards);

    // Check each current item
    for (final item in currentItems) {
      final itemId = PracticeItemCard.generateItemId(item);

      // If card doesn't exist, create a new one
      if (!syncedCards.containsKey(itemId)) {
        final newCard = PracticeItemCard.createNew(item);
        syncedCards[itemId] = newCard;
      }
    }

    // Save synced cards if new ones were added
    if (syncedCards.length != storedCards.length) {
      await saveCards(syncedCards);
    }

    return syncedCards;
  }

  /// Clear all cards (for testing/reset)
  static Future<void> clearCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
