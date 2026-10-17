import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

/// Every adjective that is graded. A possessive or an ordinal has no
/// comparative, no superlative and no adverb, so it is not listed, and an
/// adjective added without a thought about its grades fails the first test.
const _graded = {
  'acer',
  'acerbus',
  'adversus',
  'albus',
  'altus',
  'antiquus',
  'apertus',
  'armatus',
  'asper',
  'ater',
  'aureus',
  'barbarus',
  'beatus',
  'bonus',
  'callidus',
  'carus',
  'celer',
  'clarus',
  'crudelis',
  'cruentus',
  'doctus',
  'durus',
  'egregius',
  'ferus',
  'finitimus',
  'fortis',
  'graecus',
  'gravis',
  'humanus',
  'immortalis',
  'impius',
  'incertus',
  'incredibilis',
  'indignus',
  'infestus',
  'iratus',
  'iustus',
  'laetus',
  'liber',
  'magnus',
  'malus',
  'maximus',
  'medius',
  'mirus',
  'miser',
  'mollis',
  'mortuus',
  'nefarius',
  'nobilis',
  'notus',
  'novus',
  'occultus',
  'omnis',
  'paratus',
  'parvus',
  'pius',
  'placidus',
  'praeclarus',
  'propinquus',
  'publicus',
  'pulcher',
  'quantus',
  'reliquus',
  'saevus',
  'salvus',
  'sceleratus',
  'stultus',
  'summus',
  'superbus',
  'talis',
  'tantus',
  'timidus',
  'tristis',
  'turpis',
  'tutus',
  'vastus',
  'verus',
  'vivus',
};

/// The comparison forms of the four suppletive adjectives, by item id.
const _suppletive = {
  'bonus': {
    'nom.sg.m.komp': 'melior',
    'nom.sg.m.sup': 'optimus',
    'adv.pos': 'bene',
    'adv.komp': 'melius',
    'adv.sup': 'optimē',
  },
  'malus': {
    'nom.sg.m.komp': 'peior',
    'nom.sg.m.sup': 'pessimus',
    // The item gives "male"; I4 keeps the rule's spelling because the two
    // differ only in a quantity mark, which the answer check ignores anyway.
    'adv.pos': 'malē',
    'adv.komp': 'peius',
    'adv.sup': 'pessimē',
  },
  'magnus': {
    'nom.sg.m.komp': 'māior',
    'nom.sg.m.sup': 'māximus',
    'adv.pos': 'māgnopere',
    'adv.komp': 'magis',
    'adv.sup': 'māximē',
  },
  'parvus': {
    'nom.sg.m.komp': 'minor',
    'nom.sg.m.sup': 'minimus',
    'adv.pos': 'parum',
    'adv.komp': 'minus',
    'adv.sup': 'minimē',
  },
};

final _comparisonKey = RegExp(r'\.(komp|sup)$|^adv\.');

Future<List<PracticeItem>> _adjectives() async {
  final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
  return items.where((item) => item.type.startsWith('Adjektiv')).toList();
}

String _shortId(PracticeItem item) => item.id.split(':').last;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exactly the graded adjectives have comparison keys', () async {
    final adjectives = await _adjectives();
    expect(adjectives.length, 89);
    final graded = {
      for (final item in adjectives)
        if (item.formOrder.any(_comparisonKey.hasMatch)) _shortId(item),
    };
    expect(graded.difference(_graded), isEmpty, reason: 'not graded');
    expect(_graded.difference(graded), isEmpty, reason: 'listed but ungraded');
  });

  test('the suppletive adjectives give their own comparison forms', () async {
    final adjectives = await _adjectives();
    final found = <String, Map<String, String>>{};
    for (final item in adjectives) {
      final expected = _suppletive[_shortId(item)];
      if (expected == null) continue;
      found[_shortId(item)] = {
        for (var i = 0; i < item.formOrder.length; i++)
          if (expected.containsKey(item.formOrder[i]))
            item.formOrder[i]: item.forms[i],
      };
    }
    expect(found, _suppletive);
  });
}
