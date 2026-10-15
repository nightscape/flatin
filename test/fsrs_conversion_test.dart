import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'fsrs_cards';

/// A card stored under the pre-2.0 content hash, with review history.
Map<String, dynamic> _storedCard(
  String itemId,
  DateTime due,
  DateTime? lastReview,
) {
  final card = fsrs.Card(
    cardId: itemId.hashCode,
    state: fsrs.State.review,
    stability: 12.5,
    difficulty: 6.25,
    due: due,
    lastReview: lastReview,
  );
  return {
    'itemId': itemId,
    'cardData': card.toMap(),
    'lastReview': lastReview?.toIso8601String(),
    'due': due.toIso8601String(),
  };
}

Future<void> _seedV1(List<Map<String, dynamic>> cards) async {
  SharedPreferences.setMockInitialValues({
    _storageKey: jsonEncode({'version': '1.0', 'cards': cards}),
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
  final lastReview = DateTime.utc(2026, 1, 2, 3, 4, 5);

  test('v1.0 cards move to the item id, unknown ids stay, version becomes 2.0',
      () async {
    final items = await _allItems();
    final converted = items.take(3).toList();
    await _seedV1([
      for (final item in converted)
        _storedCard(PracticeItemCard.legacyHashId(item), due, lastReview),
      _storedCard('deadbeef', due, lastReview),
    ]);

    final cards = await FsrsStorage.syncCards(items);

    for (final item in converted) {
      final card = cards[PracticeItemCard.generateItemId(item)]!;
      expect(card.due, due);
      expect(card.lastReview, lastReview);
      expect(card.card.state, fsrs.State.review);
      expect(card.card.stability, 12.5);
      expect(card.card.difficulty, 6.25);
      expect(cards.containsKey(PracticeItemCard.legacyHashId(item)), isFalse);
    }
    expect(cards['deadbeef']!.due, due);
    expect((await _readStorage())['version'], '2.0');

    // A second load must be a no-op.
    final again = await FsrsStorage.syncCards(items);
    expect(again.length, cards.length);
    for (final entry in cards.entries) {
      expect(again[entry.key]!.due, entry.value.due);
      expect(again[entry.key]!.lastReview, entry.value.lastReview);
    }
  });

  test('two old cards on one item: the later-reviewed one survives', () async {
    final items = await _allItems();
    final amicus = items.firstWhere(
      (item) => PracticeItemCard.generateItemId(item) == 'nouns:amicus',
    );
    final later = DateTime.utc(2026, 6, 1);
    const deletedCopy =
        '6001ff8ac8ceffbb7cea304a442a84c4b29635ed9866b26508a32681416dca7d';

    await _seedV1([
      _storedCard(PracticeItemCard.legacyHashId(amicus), due, lastReview),
      _storedCard(deletedCopy, DateTime.utc(2031), later),
    ]);

    final cards = await FsrsStorage.syncCards(items);
    expect(cards['nouns:amicus']!.lastReview, later);
    expect(cards['nouns:amicus']!.due, DateTime.utc(2031));
    expect(cards.containsKey(deletedCopy), isFalse);
  });

  test('an unreviewed card loses against a reviewed one', () async {
    final items = await _allItems();
    final amicus = items.firstWhere(
      (item) => PracticeItemCard.generateItemId(item) == 'nouns:amicus',
    );
    const deletedCopy =
        '6001ff8ac8ceffbb7cea304a442a84c4b29635ed9866b26508a32681416dca7d';

    await _seedV1([
      _storedCard(PracticeItemCard.legacyHashId(amicus), due, lastReview),
      _storedCard(deletedCopy, DateTime.utc(2031), null),
    ]);

    final cards = await FsrsStorage.syncCards(items);
    expect(cards['nouns:amicus']!.lastReview, lastReview);
    expect(cards['nouns:amicus']!.due, due);
  });

  test('syncCards creates no second card for a converted item', () async {
    final items = await _allItems();
    await _seedV1([
      for (final item in items)
        _storedCard(PracticeItemCard.legacyHashId(item), due, lastReview),
    ]);

    final cards = await FsrsStorage.syncCards(items);

    expect(cards.length, items.length);
    for (final card in cards.values) {
      expect(card.due, due, reason: '${card.itemId} was recreated as new');
    }
  });
}
