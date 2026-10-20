import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

/// Run with GERMAN_GOLDEN_UPDATE=1 to rewrite the golden tables.
const _goldenDir = 'test/golden';

/// Their German verbs carry `absent: *ohne_passiv`.
const _withoutGermanPassive = {
  'verbs:venire',
  'verbs:cavere',
  'verbs:laborare',
  'verbs:scire',
};

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

  test('covers exactly the items with a German verb', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final covered = items.where(german.covers).map((i) => i.id).toSet();
    expect(covered, german.germanVerbOf.keys.toSet());
    expect(items.any((i) => !german.covers(i)), isTrue);
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    expect(nouns.any(german.covers), isFalse);
  });

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

  final tables = {
    'german_forms_table.md': (List<String> codes) => codes.length != 5,
    for (final person in ['1', '2', '3'])
      'german_forms_person$person.md': (List<String> codes) =>
          codes.length == 5 && codes[3] == person,
  };
  for (final MapEntry(key: name, value: inTable) in tables.entries) {
    test('every course form of the ten verbs renders as in $name', () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final rows = <String>[
        '| Latin verb | key | Latin form | German form | also accepted |',
        '| --- | --- | --- | --- | --- |',
      ];
      for (final id in german.germanVerbOf.keys) {
        final item = verbs.singleWhere((i) => i.id == id);
        final shown = <String>{};
        for (final (index, key) in item.formOrder.indexed) {
          final codes = key.split('.');
          if (!_inCourse(codes) || !inTable(codes)) continue;
          final germanKey = GrammarGermanForms.germanKeyOf(key);
          if (!shown.add(germanKey)) continue;
          final List<String> texts;
          if (codes[2] == 'pass' && _withoutGermanPassive.contains(id)) {
            expect(() => german.render(item, key), throwsArgumentError);
            texts = ['—'];
          } else {
            texts = german.accepted(item, key);
            expect(german.render(item, key), texts.first);
          }
          rows.add(
            '| ${item.lemma} | $germanKey | ${item.forms[index]} '
            '| ${texts.first} | ${texts.skip(1).join('; ')} |',
          );
        }
      }
      final table = '${rows.join('\n')}\n';
      final golden = File('$_goldenDir/$name');
      if (Platform.environment['GERMAN_GOLDEN_UPDATE'] == '1') {
        golden.writeAsStringSync(table);
      }
      expect(table, golden.readAsStringSync());
    });
  }

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
