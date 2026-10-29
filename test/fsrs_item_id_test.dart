import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart' show normalizeDiacritics;
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/test_axes.dart';

PracticeItem _item(String dataFileId, String lemma, String translation) =>
    PracticeItem(
      id: '$dataFileId:${normalizeDiacritics(lemma).toLowerCase()}',
      lemma: lemma,
      type: 'A-Deklination',
      translation: translation,
      bookTranslation: translation,
      principalParts: [('', lemma)],
      forms: const ['x'],
      acceptedForms: const [
        ['x'],
      ],
      formLabels: [nounLabel('nom', 'sg')],
      dataFileId: dataFileId,
      formOrder: const ['nominative_singular'],
      baseFormKeys: const [],
      derivation: Derivation(
        type: 'A-Deklination',
        recognition: const TypeDeclared(),
        forms: const {},
        grammar: const Grammar({}, {}, {}, 'de'),
      ),
    );

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every item has a "<dataFileId>:<lemma>" id and all ids are unique',
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
    },
  );

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
}
