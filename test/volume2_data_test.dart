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

/// The verb item ids of volume 1. A card keeps its review history only as long
/// as its id stays, so none of these may disappear.
const _volume1VerbIds = [
  'verbs:aedificare',
  'verbs:agere',
  'verbs:amare',
  'verbs:ambulare',
  'verbs:apparere',
  'verbs:apportare',
  'verbs:appropinquare',
  'verbs:audire',
  'verbs:capere',
  'verbs:cenare',
  'verbs:cessare',
  'verbs:clamare',
  'verbs:convenire',
  'verbs:curare',
  'verbs:dare',
  'verbs:delectare',
  'verbs:desiderare',
  'verbs:dicere',
  'verbs:dormire',
  'verbs:ducere',
  'verbs:esse',
  'verbs:explicare',
  'verbs:exspectare',
  'verbs:ferre',
  'verbs:fugare',
  'verbs:gaudere',
  'verbs:habere',
  'verbs:imperare',
  'verbs:intrare',
  'verbs:ire',
  'verbs:laborare',
  'verbs:legere',
  'verbs:malle',
  'verbs:manere',
  'verbs:mittere',
  'verbs:necare',
  'verbs:nolle',
  'verbs:parare',
  'verbs:parere',
  'verbs:placere',
  'verbs:ponere',
  'verbs:portare',
  'verbs:posse',
  'verbs:probare',
  'verbs:prohibere',
  'verbs:properare',
  'verbs:pugnare',
  'verbs:regnare',
  'verbs:respondere',
  'verbs:ridere',
  'verbs:rogare',
  'verbs:sacrificare',
  'verbs:salutare',
  'verbs:scire',
  'verbs:scribere',
  'verbs:sedere',
  'verbs:servare',
  'verbs:servire',
  'verbs:spectare',
  'verbs:stupere',
  'verbs:superare',
  'verbs:tacere',
  'verbs:temptare',
  'verbs:timere',
  'verbs:velle',
  'verbs:venire',
  'verbs:videre',
  'verbs:vincere',
  'verbs:visitare',
  'verbs:vocare',
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

  test('no verb of volume 1 lost its item id', () {
    expect(verbs.map((i) => i.id).toSet(), containsAll(_volume1VerbIds));
  });

  test('every verb item generates forms', () {
    for (final item in verbs) {
      expect(item.formOrder, isNotEmpty, reason: item.id);
      expect(item.forms, everyElement(isNotEmpty), reason: item.id);
      expect(item.forms.length, item.formOrder.length, reason: item.id);
    }
  });

  test('a compound follows its irregular base', () {
    String form(String itemId, String key) {
      final item = byId(verbs, itemId);
      return item.forms[item.formOrder.indexOf(key)];
    }

    expect(form('verbs:afferre', 'ind.praes.akt.2.sg'), 'affers');
    expect(form('verbs:afferre', 'ind.perf.akt.1.sg'), 'attulī');
    expect(form('verbs:abire', 'ind.praes.akt.3.pl'), 'abeunt');
    expect(form('verbs:abire', 'inf.praes.akt'), 'abīre');
    expect(form('verbs:praeesse', 'ind.praes.akt.1.sg'), 'praesum');
    expect(form('verbs:praeesse', 'konj.impf.akt.3.sg'), 'praeesset');
  });
}
