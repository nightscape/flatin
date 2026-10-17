// The Komposita of esse derive their forms; none of them is written out.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:yaml/yaml.dart';

const _compounds = [
  'verbs:posse',
  'verbs:abesse',
  'verbs:adesse',
  'verbs:deesse',
  'verbs:praeesse',
];

const _infinitives = ['posse', 'abesse', 'adesse', 'dēesse', 'praeesse'];

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
        kinds.entries.where((e) => e.value == 'IrregularForm').map((e) => e.key),
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

  test('posse writes the contracted konj. impf. from its present stem',
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
  });
}
