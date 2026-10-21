import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

/// Latin items 142..188 of latin_verbs.yaml: lemma → German verb id.
const _range = {
  'cupere': 'begehren',
  'temperāre': 'mäßigen',
  'caedere': 'niederschlagen',
  'exīstimāre': 'beurteilen',
  'alere': 'ernähren',
  'crēdere': 'glauben',
  'exstinguere': 'auslöschen',
  'adiuvāre': 'unterstützen',
  'colere': 'bebauen',
  'dēpōnere': 'ablegen',
  'iactāre': 'werfen',
  'āmittere': 'entlassen',
  'ascendere': 'besteigen',
  'pellere': 'stoßen',
  'committere': 'veranstalten',
  'vendere': 'verkaufen',
  'dēserere': 'verlassen',
  'aperīre': 'öffnen',
  'animadvertere': 'wahrnehmen',
  'adhibēre': 'hinzuziehen',
  'inīre': 'hineingehen',
  'cavēre': 'sich in acht nehmen',
  'praeesse': 'an der spitze stehen',
  'stāre': 'stehen',
  'studēre': 'sich bemühen',
  'dēfendere': 'verteidigen',
  'perspicere': 'genau betrachten',
  'interrogāre': 'fragen',
  'indicāre': 'anzeigen',
  'occīdere': 'niederschlagen',
  'nūntiāre': 'melden',
  'afferre': 'herbeitragen',
  'explōrāre': 'erforschen',
  'impedīre': 'hindern',
  'cōgere': 'zusammenbringen',
  'repellere': 'zurückstoßen',
  'relinquere': 'verlassen',
  'pōstulāre': 'fordern',
  'cōnferre': 'zusammentragen',
  'compōnere': 'zusammenstellen',
  'recitāre': 'vortragen',
  'laudāre': 'loben',
  'comparāre': 'bereiten',
  'lūdere': 'spielen',
  'solvere': 'lösen',
  'impetrāre': 'erreichen',
  'efficere': 'bewirken',
};

/// The German verb has no passive.
const _withoutGermanPassive = {
  'hineingehen',
  'an der spitze stehen',
  'stehen',
  'sich bemühen',
  'sich in acht nehmen',
};

const _package1Participles = {'fragen': 'gefragt', 'bereiten': 'bereitet'};

/// Until package 1 has landed, its two verbs are stubbed in.
String _withPackage1Stubs(String yaml) {
  final stubs = StringBuffer();
  for (final MapEntry(key: verb, value: participle)
      in _package1Participles.entries) {
    if (!yaml.contains('translation: {de: $verb,')) {
      stubs.write(
        '  - type: schwach\n'
        '    translation: {de: $verb, en: $verb}\n'
        '    parts: {infinitiv: $verb, partizip2: $participle}\n',
      );
    }
  }
  return '$yaml$stubs';
}

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
    _withPackage1Stubs(File('lib/data/german_verbs.yaml').readAsStringSync()),
    latinVerbs,
  );

  test('the range is Latin items 142..188 and each names its German verb', () {
    final items = latinVerbs.items.skip(141).take(47).toList();
    expect(items.map((i) => i.lemma).toList(), _range.keys.toList());
    expect({for (final i in items) i.lemma: i.deVerb}, _range);
  });

  test('every course form of the range has German text', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final inRange = items.where((i) => _range.containsKey(i.lemma)).toList();
    expect(inRange, hasLength(_range.length));
    for (final item in inRange) {
      final verb = _range[item.lemma]!;
      var covered = 0;
      for (final key in item.formOrder) {
        final codes = key.split('.');
        final inCourse = switch (codes.first) {
          'ind' || 'konj' => true,
          'inf' || 'part' => codes[1] == 'praes' || codes[1] == 'perf',
          _ => false,
        };
        if (!inCourse) continue;
        final absent =
            codes[2] == 'pass' && _withoutGermanPassive.contains(verb);
        expect(german.covers(item, key), !absent, reason: '${item.lemma} $key');
        if (absent) {
          expect(() => german.render(item, key), throwsArgumentError);
        } else {
          expect(german.render(item, key), isNotEmpty);
          covered++;
        }
      }
      expect(covered, greaterThan(0), reason: item.lemma);
    }
  });

  test('explicit parts give the spelling the templates cannot', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    String shown(String lemma, String key) =>
        german.render(items.singleWhere((i) => i.lemma == lemma), key);
    expect(shown('adiuvāre', 'ind.praes.akt.2.sg'), 'du unterstützt');
    expect(shown('solvere', 'ind.praes.akt.2.sg'), 'du löst');
    expect(shown('aperīre', 'ind.impf.akt.2.sg'), 'du öffnetest');
    expect(shown('impedīre', 'ind.praes.akt.1.pl'), 'wir hindern');
  });
}
