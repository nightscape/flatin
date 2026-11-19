import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/exam_conversion.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_exam.dart';

const _packs = 100;

typedef _Case = ({String name, Map<String, dynamic> data, Language language});

final _toyLanguage = Language.parse(
  File('test/fixtures/toy_course/toy_language.yaml').readAsStringSync(),
);

Map<String, dynamic> _plain(Object? data) =>
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

/// The two fixtures as static examples, then drawn schema 1 packs.
Iterable<_Case> _cases() sync* {
  yield (
    name: 'synthetic fixture',
    data: _plain(
      loadYaml(File('test/fixtures/exam/synthetic.exam').readAsStringSync()),
    ),
    language: latinLang,
  );
  yield (
    name: 'toy fixture',
    data: _plain(
      loadYaml(File('test/fixtures/toy_course/toy.exam').readAsStringSync()),
    ),
    language: _toyLanguage,
  );
  for (var seed = 1; seed <= _packs; seed++) {
    yield (
      name: 'seed $seed',
      data: {
        ..._plain(ExamGen(Random(seed)).exam()),
        if (seed.isOdd) 'kurs': 'c$seed',
      },
      language: latinLang,
    );
  }
}

List<String> _errors(String source, Language language) {
  try {
    parseExam(source, language);
  } on ExamRejected catch (e) {
    return [for (final x in e.errors) '${x.rule.id} ${x.path}'];
  }
  fail('the pack was accepted');
}

List<String> _convertedErrors(Map<String, dynamic> pack, Language language) {
  final Map converted;
  try {
    converted = convertSchema1(pack);
  } on ExamRejected catch (e) {
    return [for (final x in e.errors) '${x.rule.id} ${x.path}'];
  }
  return _errors(jsonEncode(converted), language);
}

/// Every key that a schema 1 pack can have, outside the codes of the language
/// file.
const _schema1Keys = {
  'schema',
  'id',
  'kurs',
  'titel',
  'lektionen',
  'von',
  'bis',
  'schwerpunkte',
  'schwerpunkt',
  'thema',
  'zeit_min',
  'punkte_uebersetzung',
  'punkte_gesamt',
  'uebersetzung',
  'hilfen',
  'saetze',
  'aufgaben',
  'lemma',
  'angabe',
  'de',
  'tokens',
  'teilsaetze',
  'la',
  'analyse',
  'rolle',
  'bezug',
  'verbform',
  'art',
  'uebergeordnet',
  'sinnrichtung',
  'ausrichtung',
  'punkte',
  'frage',
  'loesung',
  'elemente',
  'items',
  'merkmale',
  'stammformen',
  'form',
  'vorgabe',
  'ziel',
  'fremdwort',
  'stichwoerter',
  'optionen',
  'richtig',
  'teilsatz',
  'token',
};

void _keysOf(Object? node, Set<String> into) {
  if (node is Map) {
    for (final e in node.entries) {
      into.add(e.key as String);
      if (e.key != 'analyse' && e.key != 'merkmale') _keysOf(e.value, into);
    }
  } else if (node is List) {
    for (final v in node) {
      _keysOf(v, into);
    }
  }
}

void main() {
  final cases = _cases().toList();

  test('the cases use every key of schema 1 and every kind of task', () {
    final keys = <String>{};
    final types = <String>{};
    for (final c in cases) {
      _keysOf(c.data, keys);
      for (final t in c.data['aufgaben'] as List) {
        types.add(t['art'] as String);
      }
    }
    expect(_schema1Keys.difference(keys), isEmpty);
    expect(types, {
      for (final a in schema1Arts) a.schema1Code,
      'ordnen',
      'frei',
    });
  });

  test('a schema 1 pack and every written form of it in schema 2 parse to '
      'the drawn pack', () {
    for (final c in cases) {
      final one = parseExam(jsonEncode(c.data), c.language);
      expect(schema1Yaml(one), equals(c.data), reason: c.name);
      final written = examToYaml(one);
      expect(written['schema'], 2, reason: c.name);
      for (final text in [jsonEncode(written), blockYaml(written)]) {
        final two = parseExam(text, c.language);
        expect(schema1Yaml(two), equals(c.data), reason: c.name);
        expect(examToYaml(two), equals(written), reason: c.name);
      }
    }
  });

  test('a schema 1 pack converts to the pack that the schema 2 writer '
      'writes', () {
    for (final c in cases) {
      final written = examToYaml(parseExam(jsonEncode(c.data), c.language));
      expect(convertSchema1(c.data), equals(written), reason: c.name);
    }
  });

  test('the fixtures read as the Exam of the stored serialization', () {
    for (final (fixture, golden, language) in [
      (
        'test/fixtures/exam/synthetic.exam',
        'test/fixtures/exam/synthetic.schema1.golden.json',
        latinLang,
      ),
      (
        'test/fixtures/toy_course/toy.exam',
        'test/fixtures/exam/toy.schema1.golden.json',
        _toyLanguage,
      ),
    ]) {
      final exam = parseExam(File(fixture).readAsStringSync(), language);
      final stored = jsonDecode(File(golden).readAsStringSync());
      expect(
        jsonDecode(serializeExam(exam)),
        equals(convertSchema1(stored as Map)),
        reason: fixture,
      );
    }
  });

  test('each broken rule is refused with the same rule and path in schema 1 '
      'and in schema 2', () {
    final reached = <ExamRule>{};
    for (final rule in latinRules) {
      if (rule == ExamRule.yaml) continue;
      var seed = 0;
      for (final c in cases.where((c) => c.language == latinLang)) {
        final broken = _plain(c.data);
        final path = breakRule(rule, broken, Random(seed++));
        if (path == null) continue;
        reached.add(rule);
        final want = '${rule.id} $path';
        final one = _errors(jsonEncode(broken), c.language);
        expect(one, contains(want), reason: '${c.name} ${rule.id}');
        if (rule == ExamRule.schema) continue;
        final two = _convertedErrors(broken, c.language);
        expect(two, equals(one), reason: '${c.name} ${rule.id}');
      }
    }
    expect(
      {
        for (final rule in latinRules)
          if (rule != ExamRule.yaml) rule,
      }.difference(reached),
      isEmpty,
    );
  });

  test('a key of the other schema is refused, and so is schema 3', () {
    for (final (i, c) in cases.indexed) {
      final mixed = _plain(c.data);
      final path = addSchema2Key(mixed, Random(i));
      expect(
        _errors(jsonEncode(mixed), c.language),
        equals(['${ExamRule.key.id} $path']),
        reason: c.name,
      );
      final pack = examToYaml(parseExam(jsonEncode(c.data), c.language));
      expect(
        _errors(jsonEncode({...pack, 'titel': 'x'}), c.language),
        equals(['${ExamRule.key.id} exam.titel']),
        reason: c.name,
      );
      expect(
        _errors(jsonEncode({...pack, 'schema': 3}), c.language),
        equals(['${ExamRule.schema.id} exam.schema']),
        reason: c.name,
      );
    }
  });
}
