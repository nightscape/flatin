import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'fsrs_cards';

Map<String, dynamic> _storedCard(String itemId, DateTime due) {
  final card = fsrs.Card(
    cardId: itemId.hashCode,
    state: fsrs.State.review,
    stability: 12.5,
    difficulty: 6.25,
    due: due,
    lastReview: due,
  );
  return {
    'itemId': itemId,
    'cardData': card.toMap(),
    'lastReview': due.toIso8601String(),
    'due': due.toIso8601String(),
  };
}

Future<void> _seed(String version, List<Map<String, dynamic>> cards) async {
  SharedPreferences.setMockInitialValues({
    _storageKey: jsonEncode({'version': version, 'cards': cards}),
  });
}

Future<Map<String, dynamic>> _readStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(_storageKey)!) as Map<String, dynamic>;
}

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final due = DateTime.utc(2030, 1, 2, 3, 4, 5);

  test(
    'a v1.0 store is discarded and replaced by an empty 2.0 store',
    () async {
      final items = await _allItems();
      await _seed('1.0', [
        _storedCard(PracticeItemCard.generateItemId(items.first), due),
        _storedCard('deadbeef', due),
      ]);

      expect(await FsrsStorage.loadCards(), isEmpty);
      expect(await _readStorage(), {'version': '2.0', 'cards': <dynamic>[]});
    },
  );

  test('a 2.0 store keeps its cards', () async {
    final items = await _allItems();
    final itemId = PracticeItemCard.generateItemId(items.first);
    await _seed('2.0', [_storedCard(itemId, due)]);

    final cards = await FsrsStorage.loadCards();
    expect(cards.keys, [itemId]);
    expect(cards[itemId]!.due, due);
  });

  test(
    'syncCards over a discarded v1.0 store gives every item a new card',
    () async {
      final items = await _allItems();
      await _seed('1.0', [
        for (final item in items)
          _storedCard(PracticeItemCard.generateItemId(item), due),
      ]);

      final cards = await FsrsStorage.syncCards(items);

      expect(cards.length, items.length);
      for (final card in cards.values) {
        expect(
          card.due,
          isNot(due),
          reason: '${card.itemId} kept its v1.0 card',
        );
      }
    },
  );
}
