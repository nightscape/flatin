import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

/// Run with GERMAN_GOLDEN_UPDATE=1 to rewrite the golden table.
const _golden = 'test/golden/german_forms_table.md';

/// German verbs with "sein" or a reflexive pronoun form no passive.
const _withoutGermanPassive = {'verbs:venire', 'verbs:cavere'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final latinVerbs = parseGrammarFiles({
    for (final path in [
      'lib/data/latin_nouns.yaml',
      'lib/data/latin_verbs.yaml',
    ])
      path: File(path).readAsStringSync(),
  }).singleWhere((f) => f.dataFileId == 'verbs');
  final german = GrammarGermanForms(
    File('lib/data/german_verbs.yaml').readAsStringSync(),
    latinVerbs,
  );

  test('the ten spike verbs name their German verb', () {
    expect(german.germanVerbOf, {
      'verbs:amare': 'lieben',
      'verbs:venire': 'kommen',
      'verbs:gaudere': 'sich freuen',
      'verbs:laborare': 'arbeiten',
      'verbs:scire': 'wissen',
      'verbs:vocare': 'rufen',
      'verbs:ferre': 'tragen',
      'verbs:esse': 'sein',
      'verbs:cavere': 'sich in acht nehmen',
      'verbs:convocare': 'zusammenrufen',
    });
  });

  test(
    'every course bundle of the ten verbs renders as in the table',
    () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final rows = <String>[
        '| Latin verb | bundle | Latin form | German form |',
        '| --- | --- | --- | --- |',
      ];
      for (final id in german.germanVerbOf.keys) {
        final item = verbs.singleWhere((i) => i.id == id);
        final shown = <String>{};
        for (final (index, key) in item.formOrder.indexed) {
          final codes = key.split('.');
          if (!_inCourse(codes)) continue;
          final bundle = codes.take(3).join('.');
          final finite = codes.length == 5;
          if (finite ? !key.endsWith('.3.pl') : !shown.add(bundle)) continue;
          final String text;
          if (codes[2] == 'pass' && _withoutGermanPassive.contains(id)) {
            expect(() => german.render(item, key), throwsArgumentError);
            text = '—';
          } else {
            text = german.render(item, key);
          }
          rows.add(
            '| ${item.lemma} | ${finite ? key : bundle} | ${item.forms[index]} '
            '| $text |',
          );
        }
      }
      final table = '${rows.join('\n')}\n';
      if (Platform.environment['GERMAN_GOLDEN_UPDATE'] == '1') {
        File(_golden).writeAsStringSync(table);
      }
      expect(table, File(_golden).readAsStringSync());
    },
  );

  test('a form outside the course convention has no German text', () async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    for (final key in ['imp.praes.akt.2.sg', 'inf.fut.akt', 'ger.gen']) {
      expect(() => german.render(vocare, key), throwsArgumentError);
    }
  });
}

bool _inCourse(List<String> codes) => switch (codes.first) {
  'ind' || 'konj' => true,
  'inf' || 'part' => codes[1] == 'praes' || codes[1] == 'perf',
  _ => false,
};
