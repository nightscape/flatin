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

Future<void> _seed(String raw) async {
  SharedPreferences.setMockInitialValues({_storageKey: raw});
}

Future<String?> _rawStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_storageKey);
}

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupted stored JSON throws and leaves the stored bytes alone',
      () async {
    const corrupted = '{"version": "2.0", "cards": [';
    await _seed(corrupted);
    final items = await _allItems();

    await expectLater(
      FsrsStorage.syncCards(items),
      throwsA(isA<FormatException>()),
    );
    expect(await _rawStorage(), corrupted);
  });

  test('a card with a malformed field throws and leaves the stored bytes alone',
      () async {
    final items = await _allItems();
    final healthy = _storedCard(
      PracticeItemCard.generateItemId(items.first),
      DateTime.utc(2030),
    );
    final malformed = _storedCard('deadbeef', DateTime.utc(2030))
      ..['due'] = 'not-a-date';
    final raw = jsonEncode({
      'version': '2.0',
      'cards': [healthy, malformed],
    });
    await _seed(raw);

    await expectLater(
      FsrsStorage.syncCards(items),
      throwsA(isA<FormatException>()),
    );
    expect(await _rawStorage(), raw);
  });
}
