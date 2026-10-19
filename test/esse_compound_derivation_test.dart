// The Komposita of esse derive their forms; none of them is written out.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:yaml/yaml.dart';

const _compounds = [
  'verbs:posse',
  'verbs:abesse',
  'verbs:adesse',
  'verbs:deesse',
  'verbs:praeesse',
];

const _infinitives = ['posse', 'abesse', 'adesse', 'dēesse', 'praeesse'];

/// Every form of the five compounds, in the order of [_compounds] and of each
/// item's form order, as `id\tkey\tvariants joined by " / "`.
const _goldenPath = 'test/fixtures/esse_compound_forms.txt';

List<String> _formLines(Map<String, PracticeItem> byId) => [
  for (final id in _compounds)
    for (final entry in byId[id]!.derivation.forms.entries)
      '$id\t${entry.key}\t${entry.value.variants.join(' / ')}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no esse compound carries a forms block', () {
    final yaml = loadYaml(File('lib/data/latin_verbs.yaml').readAsStringSync());
    final found = <String>[];
    for (final item in yaml['items'] as YamlList) {
      final infinitiv = (item as YamlMap)['parts']?['infinitiv'];
      if (!_infinitives.contains(infinitiv)) continue;
      found.add(infinitiv as String);
      expect(item['forms'], isNull, reason: '$infinitiv writes forms out');
    }
    expect(found, unorderedEquals(_infinitives));
  });

  test('every form of an esse compound comes from a rule', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final byId = {for (final item in items) item.id: item};

    for (final id in _compounds) {
      final item = byId[id];
      expect(item, isNotNull, reason: '$id is gone');
      final kinds = <String, String>{
        for (final entry in item!.derivation.forms.entries)
          entry.key: entry.value.runtimeType.toString(),
      };
      expect(
        kinds.entries
            .where((e) => e.value == 'IrregularForm')
            .map((e) => e.key),
        isEmpty,
        reason: '$id: these keys are written out instead of derived',
      );
      expect(kinds, isNotEmpty, reason: id);
    }
  });

  test('the present system of a compound is esse plus the prefix', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final byId = {for (final item in items) item.id: item};

    for (final (id, key, prefix, esseForm) in const [
      ('verbs:abesse', 'ind.praes.akt.1.sg', 'ab', 'sum'),
      ('verbs:abesse', 'konj.impf.akt.3.pl', 'ab', 'essent'),
      ('verbs:abesse', 'inf.praes.akt', 'ab', 'esse'),
      ('verbs:adesse', 'imp.fut.akt.3.pl', 'ad', 'suntō'),
      ('verbs:deesse', 'ind.fut.akt.1.sg', 'dē', 'erō'),
      ('verbs:praeesse', 'ind.praes.akt.3.sg', 'prae', 'est'),
      // pot + sum: the t_s rule writes the first s of possum.
      ('verbs:posse', 'ind.praes.akt.1.sg', 'pos', 'sum'),
      ('verbs:posse', 'ind.impf.akt.3.sg', 'pot', 'erat'),
      ('verbs:posse', 'konj.praes.akt.1.pl', 'pos', 'sīmus'),
    ]) {
      final form = byId[id]!.derivation.forms[key];
      expect(form, isA<ComposedForm>(), reason: '$id / $key');
      final parts = (form as ComposedForm).parts;
      expect(parts.length, 2, reason: '$id / $key');
      expect((parts[0] as AffixPart).text, prefix, reason: '$id / $key');
      final lexeme = parts[1] as LexemeFormPart;
      expect(lexeme.lexemeId, 'esse', reason: '$id / $key');
      expect(lexeme.derivation.result, esseForm, reason: '$id / $key');
    }
  });

  test('the compounds keep the spellings the golden records', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final got = _formLines({for (final item in items) item.id: item});
    final want = File(_goldenPath).readAsLinesSync();

    for (var i = 0; i < want.length && i < got.length; i++) {
      expect(got[i], want[i], reason: '$_goldenPath line ${i + 1}');
    }
    expect(got.length, want.length, reason: 'number of lines');
  });

  test(
    'abesse and praeesse have a present participle, the others none',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final byId = {for (final item in items) item.id: item};

      for (final (id, nom, gen) in const [
        ('verbs:abesse', 'absēns', 'absentis'),
        ('verbs:praeesse', 'praesēns', 'praesentis'),
      ]) {
        final forms = byId[id]!.derivation.forms;
        expect(forms['part.praes.akt.sg.nom.m']!.result, nom, reason: id);
        expect(forms['part.praes.akt.sg.gen.n']!.result, gen, reason: id);
        expect(forms['part.praes.akt.sg.nom.m'], isNot(isA<IrregularForm>()));
      }
      for (final id in const ['verbs:adesse', 'verbs:deesse']) {
        expect(
          byId[id]!.derivation.forms.keys.where(
            (k) => k.startsWith('part.praes'),
          ),
          isEmpty,
          reason: '$id has no present participle',
        );
      }
    },
  );

  test('every compound has a future participle from futūrus', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final byId = {for (final item in items) item.id: item};

    for (final (id, nom, abl) in const [
      ('verbs:abesse', 'āfutūrus', 'āfutūrō'),
      ('verbs:adesse', 'adfutūrus', 'adfutūrō'),
      ('verbs:deesse', 'dēfutūrus', 'dēfutūrō'),
      ('verbs:praeesse', 'praefutūrus', 'praefutūrō'),
    ]) {
      final forms = byId[id]!.derivation.forms;
      expect(forms['part.fut.akt.sg.nom.m']!.result, nom, reason: id);
      expect(forms['part.fut.akt.sg.abl.n']!.result, abl, reason: id);
      expect(forms['part.fut.akt.sg.nom.m'], isNot(isA<IrregularForm>()));
    }
  });

  test(
    'no compound has a perfect participle, gerund, supine or future infinitive',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final byId = {for (final item in items) item.id: item};

      for (final id in _compounds.skip(1)) {
        expect(
          byId[id]!.derivation.forms.keys.where(
            (k) =>
                k.startsWith('part.perf') ||
                k.startsWith('ger.') ||
                k.startsWith('sup.') ||
                k.startsWith('inf.fut'),
          ),
          isEmpty,
          reason: id,
        );
      }
    },
  );

  test(
    'posse writes the contracted konj. impf. from its present stem',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final posse = items.singleWhere((item) => item.id == 'verbs:posse');

      for (final (key, expected) in const [
        ('konj.impf.akt.1.sg', 'possem'),
        ('konj.impf.akt.2.pl', 'possētis'),
        ('inf.praes.akt', 'posse'),
      ]) {
        final form = posse.derivation.forms[key];
        expect(form, isA<GeneratedForm>(), reason: key);
        expect((form as GeneratedForm).stemName, 'praesens', reason: key);
        expect(form.result, expected, reason: key);
      }
    },
  );
}
