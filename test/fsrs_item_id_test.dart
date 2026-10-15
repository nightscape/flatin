import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';

/// `legacyHashId` of every item whose lemma had a duplicate, taken from
/// main@7a16791d before the duplicates were removed. The surviving item must
/// keep its hash, otherwise the conversion cannot find its stored card.
const _legacyHashesAtBase = {
  'nouns:amicus':
      '0c43f01737f40848f927b5ceed644f3145e7aa34a01018b3ca5af4e8e94f4d7d',
  'nouns:romanus':
      '1744e5ac6b2df81893036ba395cf9e9d502d16801f5370d4e0cda406d5bfcade',
  'nouns:filius':
      '5bf2b9fd6b69557f6739570877306d8e16e1b5bf3becea131e6ca50d59c6e863',
  'nouns:filia':
      'd80e74f633303107dfb594c7cafb13a6982eacc45a3a90e58f20686cf2093b5d',
  'nouns:femina':
      '9813f040fc063b66ef657b7a18e38f834ffba39585a2b07eb859808c0672676b',
  'verbs:amare':
      'd352d391c7154fec3ef92f712b371faee2a2173f591a2380a204ad269239f773',
  'verbs:habere':
      '403daa56883296a4078c9d8cf64c7f8fec61e6c0f67a6b28c89522ce0a1f63fd',
  'verbs:audire':
      'bbf8c3979f1a78be91c66307676313126fe82829441d430b3b41063d7021d1da',
  'verbs:venire':
      'd2ddaa3b82f65c4d677b349712b6f28702bffdfbe20996ab90fe64cc92da429f',
  'verbs:apparere':
      '4b712c7439d0eb55a3c8ed256480711c7f12edaac97867dc88e10cbadbee0a38',
};

PracticeItem _item(String dataFileId, String word, String translation) =>
    PracticeItem(
      type: 'A-Deklination',
      translation: translation,
      word: word,
      forms: const ['x'],
      formLabels: [FormLabel(name: 'Nominativ', number: 'Singular')],
      classificationSections: const [],
      dataFileId: dataFileId,
      formOrder: const ['nominative_singular'],
      derivation: Derivation(
        type: 'A-Deklination',
        recognition: const TypeDeclared(),
        forms: const {},
        grammar: const Grammar({}),
      ),
    );

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every item has a "<dataFileId>:<lemma>" id and all ids are unique',
      () async {
    final items = await _allItems();
    expect(items, isNotEmpty);

    final seen = <String>{};
    for (final item in items) {
      final itemId = PracticeItemCard.generateItemId(item);
      expect(
        itemId,
        matches(RegExp(r'^(nouns|verbs):[^:]+$')),
        reason: '${item.translation} has an unexpected id',
      );
      expect(itemId.startsWith('${item.dataFileId}:'), isTrue);
      expect(seen.add(itemId), isTrue, reason: 'duplicate id $itemId');
    }

    PracticeItemCard.assertUniqueItemIds(items);
  });

  test('two items with the same lemma throw and name both translations', () {
    expect(
      () => PracticeItemCard.assertUniqueItemIds([
        _item('nouns', 'fēmina', 'die Frau'),
        _item('nouns', 'femina', 'das Weib'),
      ]),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('nouns:femina'),
            contains('die Frau'),
            contains('das Weib'),
          ),
        ),
      ),
    );
  });

  test('deduplicated items kept their legacy hash', () async {
    final items = await _allItems();
    final byItemId = {
      for (final item in items) PracticeItemCard.generateItemId(item): item,
    };

    for (final entry in _legacyHashesAtBase.entries) {
      final item = byItemId[entry.key];
      expect(item, isNotNull, reason: '${entry.key} disappeared');
      expect(
        PracticeItemCard.legacyHashId(item!),
        entry.value,
        reason: 'legacy hash of ${entry.key} changed; stored cards would be '
            'orphaned',
      );
    }
  });
}
