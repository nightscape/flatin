import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';

class FsrsStorage {
  static const String _storageKey = 'fsrs_cards';
  static const String _currentVersion = '2.0';

  /// Load all FSRS cards from storage.
  ///
  /// A store written by another version is discarded and replaced by an empty
  /// 2.0 store: the learner starts the scheduling over, which is cheaper than
  /// carrying a migration path for every past id scheme.
  ///
  /// A read or parse error throws: an empty map would make [syncCards]
  /// overwrite the learner's whole review history with new cards.
  static Future<Map<String, PracticeItemCard>> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final cardsJson = prefs.getString(_storageKey);

    if (cardsJson == null) {
      return {};
    }

    final json = jsonDecode(cardsJson) as Map<String, dynamic>;

    if (json['version'] != _currentVersion) {
      await saveCards({});
      return {};
    }

    final cardsList = json['cards'] as List<dynamic>;
    final cardsMap = <String, PracticeItemCard>{};

    for (final cardData in cardsList) {
      final card = PracticeItemCard.fromMap(cardData as Map<String, dynamic>);
      cardsMap[card.itemId] = card;
    }

    return cardsMap;
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

    final storedCards = await loadCards();
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
