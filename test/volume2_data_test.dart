import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

/// The volume-2 types that carry explicit forms only: they have no pattern.
const _explicitTypes = [
  'Pronomen-personal',
  'Pronomen-is',
  'Pronomen-idem',
  'Pronomen-hic',
  'Pronomen-ille',
  'Pronomen-iste',
  'Pronomen-ipse',
  'Pronomen-qui',
  'Pronomen-quis',
  'Numerale-unus',
  'Numerale-duo',
  'Numerale-tres',
  'Numerale-milia',
];

List<String> _keys(List<String> numbers, {bool genus = false}) => [
      for (final number in numbers)
        for (final kasus in ['nom', 'gen', 'dat', 'akk', 'abl'])
          if (genus)
            for (final g in ['m', 'f', 'n']) '$kasus.$number.$g'
          else
            '$kasus.$number',
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;
  late List<PracticeItem> verbs;

  setUpAll(() async {
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  });

  PracticeItem byId(List<PracticeItem> items, String itemId) =>
      items.singleWhere((i) => i.id == itemId);

  test('every explicit-forms type of volume 2 has at least one item', () {
    final types = nouns.map((i) => i.type).toSet();
    for (final type in _explicitTypes) {
      expect(types, contains(type));
    }
  });

  test('defective paradigms expose only the numbers they have', () {
    expect(byId(nouns, 'nouns:ego').formOrder, _keys(['sg']));
    expect(byId(nouns, 'nouns:nos').formOrder, _keys(['pl']));
    expect(byId(nouns, 'nouns:milia').formOrder, _keys(['pl']));
    expect(byId(nouns, 'nouns:quis').formOrder.toSet(),
        _keys(['sg'], genus: true).toSet());
    expect(byId(nouns, 'nouns:unus').formOrder.toSet(),
        _keys(['sg'], genus: true).toSet());
    expect(byId(nouns, 'nouns:tres').formOrder.toSet(),
        _keys(['pl'], genus: true).toSet());
    // The full pronouns keep both numbers.
    expect(byId(nouns, 'nouns:hic').formOrder.toSet(),
        _keys(['sg', 'pl'], genus: true).toSet());
  });

  test('Futur I is practised for every conjugation', () {
    final futurKeys = [
      'ind.fut.akt.1.sg',
      'ind.fut.akt.2.sg',
      'ind.fut.akt.3.sg',
      'ind.fut.akt.1.pl',
      'ind.fut.akt.2.pl',
      'ind.fut.akt.3.pl',
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
