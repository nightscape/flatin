import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

const _path = 'lib/data/latin_nouns.yaml';
const _erType = 'O-Deklination-er';

/// A 2nd-declension noun in -er: the nominative and the genitive singular.
typedef ErNoun = ({String nom, String gen});

const _letters = ['a', 'ā', 'e', 'ē', 'i', 'ī', 'o', 'u', 'l', 'm', 'n', 's'];
const _consonants = ['b', 'c', 'd', 'f', 'g', 'p', 't'];

String _prefix(Random rng) => [
  for (var i = 0; i < 1 + rng.nextInt(3); i++)
    _letters[rng.nextInt(_letters.length)],
].join();

/// Both kinds: the e drops before the r (ager, agrī) or stays (puer, puerī).
ErNoun drawErNoun(Random rng) {
  final p = _prefix(rng);
  if (rng.nextBool()) return (nom: '${p}er', gen: '${p}erī');
  final c = _consonants[rng.nextInt(_consonants.length)];
  return (nom: '$p${c}er', gen: '$p${c}rī');
}

const _examples = <ErNoun>[
  (nom: 'ager', gen: 'agrī'),
  (nom: 'puer', gen: 'puerī'),
];

String _item(String id, String? type, Map<String, String> parts) => [
  '  - id: $id',
  if (type != null) '    type: $type',
  '    translation: {de: x, en: x}',
  '    parts: {${parts.entries.map((e) => '${e.key}: "${e.value}"').join(', ')}}',
].join('\n');

GrammarEngine _engineWith(List<String> items) => GrammarEngine(
  parseGrammarFiles({
    _path: '${File(_path).readAsStringSync()}\n${items.join('\n')}\n',
  }),
);

void main() {
  test('a noun of the -er type declines like a 2nd-declension masculine on '
      'its genitive stem, with the nominative as the vocative', () {
    final rng = Random(361);
    final nouns = [..._examples, for (var i = 0; i < 40; i++) drawErNoun(rng)];
    final engine = _engineWith([
      for (final (i, n) in nouns.indexed) ...[
        _item('er$i', _erType, {'nom': n.nom, 'gen': n.gen}),
        _item('us$i', 'O-Deklination-maskulinum', {
          'nom': '${n.gen.substring(0, n.gen.length - 1)}us',
        }),
      ],
    ]);
    for (final (i, n) in nouns.indexed) {
      final er = engine.of('nouns', 'er$i').forms;
      final us = engine.of('nouns', 'us$i').forms;
      expect(er.keys.toSet(), us.keys.toSet(), reason: n.nom);
      for (final key in er.keys) {
        final want = key == 'nom.sg' || key == 'vok.sg'
            ? [n.nom]
            : us[key]!.variants;
        expect(er[key]!.variants, want, reason: '${n.nom} $key');
      }
    }
  });

  test('no -er noun without a type is read as the -er type', () {
    final rng = Random(3610);
    final nouns = [..._examples, for (var i = 0; i < 20; i++) drawErNoun(rng)];
    for (final n in nouns) {
      final source = {
        _path:
            '${File(_path).readAsStringSync()}\n'
            '${_item('probe', null, {'nom': n.nom, 'gen': n.gen})}\n',
      };
      expect(
        () => parseGrammarFiles(source),
        throwsA(
          predicate(
            (e) => '$e'.contains('no type_inference rule matches'),
            'the S11 error',
          ),
        ),
        reason: '${n.nom} has no type rule and must give its type',
      );
    }
  });
}
