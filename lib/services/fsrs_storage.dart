import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/practice_item.dart';
import '../models/fsrs_card.dart';

class FsrsStorage {
  static const String _storageKey = 'fsrs_cards';
  static const String _currentVersion = '1.0';

  /// Load all FSRS cards from storage
  static Future<Map<String, PracticeItemCard>> loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = prefs.getString(_storageKey);

      if (cardsJson == null) {
        return {};
      }

      final json = jsonDecode(cardsJson) as Map<String, dynamic>;

      // Check version for future migrations
      final version = json['version'] as String? ?? '0.0';
      if (version != _currentVersion) {
        // Handle version migration if needed in the future
      }

      final cardsList = json['cards'] as List<dynamic>? ?? [];
      final cardsMap = <String, PracticeItemCard>{};

      for (final cardData in cardsList) {
        try {
          final card = PracticeItemCard.fromMap(
            cardData as Map<String, dynamic>,
          );
          cardsMap[card.itemId] = card;
        } catch (e) {
          // Skip invalid cards
          print('Error loading card: $e');
        }
      }

      return cardsMap;
    } catch (e) {
      print('Error loading FSRS cards: $e');
      return {};
    }
  }

  /// Save all FSRS cards to storage
  static Future<void> saveCards(Map<String, PracticeItemCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsList = cards.values.map((card) => card.toMap()).toList();

      final json = {'version': _currentVersion, 'cards': cardsList};

      final cardsJson = jsonEncode(json);
      await prefs.setString(_storageKey, cardsJson);
    } catch (e) {
      print('Error saving FSRS cards: $e');
    }
  }

  /// Sync cards with current YAML items - creates new cards for new items
  static Future<Map<String, PracticeItemCard>> syncCards(
    List<PracticeItem> currentItems,
  ) async {
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

  /// Get a card for a specific item
  static Future<PracticeItemCard?> getCardForItem(PracticeItem item) async {
    final cards = await loadCards();
    final itemId = PracticeItemCard.generateItemId(item);
    return cards[itemId];
  }

  /// Update a specific card
  static Future<void> updateCard(PracticeItemCard card) async {
    final cards = await loadCards();
    cards[card.itemId] = card;
    await saveCards(cards);
  }

  /// Clear all cards (for testing/reset)
  static Future<void> clearCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing FSRS cards: $e');
    }
  }
}
