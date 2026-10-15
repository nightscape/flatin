import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';

/// The volume-2 types that carry explicit forms only. They have no pattern, so
/// `form_inference_test.dart` never looks at them.
const _explicitTypes = [
  'Pronomen-personal',
  'Pronomen-hic-maskulinum',
  'Pronomen-hic-femininum',
  'Pronomen-hic-neutrum',
  'Pronomen-ille-maskulinum',
  'Pronomen-ille-femininum',
  'Pronomen-ille-neutrum',
  'Pronomen-iste-maskulinum',
  'Pronomen-iste-femininum',
  'Pronomen-iste-neutrum',
  'Pronomen-ipse-maskulinum',
  'Pronomen-ipse-femininum',
  'Pronomen-ipse-neutrum',
  'Pronomen-qui-maskulinum',
  'Pronomen-qui-femininum',
  'Pronomen-qui-neutrum',
  'Pronomen-quis-maskulinum-femininum',
  'Pronomen-quis-neutrum',
  'Numerale-unus-maskulinum',
  'Numerale-unus-femininum',
  'Numerale-unus-neutrum',
  'Numerale-tres-maskulinum-femininum',
  'Numerale-tres-neutrum',
  'Numerale-milia',
];

const _singular = [
  'nominative_singular',
  'genitive_singular',
  'dative_singular',
  'accusative_singular',
  'ablative_singular',
];

const _plural = [
  'nominative_plural',
  'genitive_plural',
  'dative_plural',
  'accusative_plural',
  'ablative_plural',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;
  late List<PracticeItem> verbs;

  setUpAll(() async {
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  });

  PracticeItem byId(List<PracticeItem> items, String itemId) => items
      .firstWhere((i) => PracticeItemCard.generateItemId(i) == itemId);

  test('every explicit-forms type of volume 2 has at least one item', () {
    final types = nouns.map((i) => i.type).toSet();
    for (final type in _explicitTypes) {
      expect(types, contains(type));
    }
  });

  test('defective paradigms expose only the numbers they have', () {
    expect(byId(nouns, 'nouns:ego').formOrder, _singular);
    expect(byId(nouns, 'nouns:nos').formOrder, _plural);
    expect(byId(nouns, 'nouns:quis').formOrder, _singular);
    expect(byId(nouns, 'nouns:unus').formOrder, _singular);
    expect(byId(nouns, 'nouns:tres').formOrder, _plural);
    expect(byId(nouns, 'nouns:milia').formOrder, _plural);
    // The full pronouns keep both numbers.
    expect(byId(nouns, 'nouns:hic').formOrder, [..._singular, ..._plural]);
  });

  test('Futur I is practised for every conjugation', () {
    final futurKeys = [
      'futur_first_person_singular',
      'futur_second_person_singular',
      'futur_third_person_singular',
      'futur_first_person_plural',
      'futur_second_person_plural',
      'futur_third_person_plural',
    ];
    for (final itemId in [
      'verbs:amare',
      'verbs:habere',
      'verbs:audire',
      'verbs:capere',
      'verbs:agere',
      'verbs:ferre',
      'verbs:posse',
      'verbs:ire',
      'verbs:velle',
      'verbs:nolle',
      'verbs:malle',
    ]) {
      final item = byId(verbs, itemId);
      expect(item.formOrder, containsAll(futurKeys), reason: itemId);
      for (final key in futurKeys) {
        expect(item.forms[item.formOrder.indexOf(key)], isNotEmpty);
      }
    }
  });
}
