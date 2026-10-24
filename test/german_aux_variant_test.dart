import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

final _path =
    Platform.environment['GERMAN_VERBS_YAML'] ?? 'lib/data/german_verbs.yaml';

void main() {
  final engine = GrammarEngine(
    parseGrammarFiles({_path: File(_path).readAsStringSync()}),
  );
  ({String? shown, List<String>? variants}) form(String id, String key) {
    final f = engine.of('german_verbs', id).forms[key]!;
    return (shown: f.result, variants: f.variants);
  }

  const expected = {
    'sitzen': ['gesessen', 'saß'],
    'liegen': ['gelegen', 'lag'],
    'stehen': ['gestanden', 'stand'],
    'segeln': ['gesegelt', 'segelte'],
  };

  for (final MapEntry(key: verb, value: [part2, _]) in expected.entries) {
    test('$verb is shown with haben and also accepted with sein', () {
      expect(form(verb, 'ind.perf.akt.3.sg').shown, 'er/sie/es hat $part2');
      expect(
        form(verb, 'ind.perf.akt.3.sg').variants,
        contains('er/sie/es ist $part2'),
      );
      expect(form(verb, 'ind.plusq.akt.1.pl').shown, 'wir hatten $part2');
      expect(
        form(verb, 'ind.plusq.akt.1.pl').variants,
        contains('wir waren $part2'),
      );
      expect(form(verb, 'ind.fut2.akt.1.sg').shown, 'ich werde $part2 haben');
      expect(
        form(verb, 'ind.fut2.akt.1.sg').variants,
        contains('ich werde $part2 sein'),
      );
    });
  }

  final sein = RegExp(
    r'\b(bin|bist|ist|sind|seid|war|warst|waren|wart|wäre|wärest|wärst|wären|wäret|wärt|sei|seist|seiest|seien|seiet|sein)\b',
  );
  for (final verb in expected.keys) {
    test('$verb accepts sein in every active perfect-family key', () {
      final keys = engine.of('german_verbs', verb).forms.keys.where((k) {
        final [modus, tempus, genus, ...] = k.split('.');
        return genus == 'akt' &&
            modus != 'part' &&
            const {'perf', 'plusq', 'fut2'}.contains(tempus);
      }).toList();
      expect(keys, isNotEmpty);
      for (final k in keys) {
        final f = form(verb, k);
        expect(sein.hasMatch(f.shown!), isFalse, reason: k);
        expect(f.variants!.any(sein.hasMatch), isTrue, reason: k);
      }
    });
  }

  test('sitzen sein variants of Konjunktiv Perfekt and Plusquamperfekt', () {
    const pronouns = {
      '1.sg': 'ich',
      '2.sg': 'du',
      '3.sg': 'er/sie/es',
      '1.pl': 'wir',
      '2.pl': 'ihr',
      '3.pl': 'sie (Pl.)',
    };
    const perf = ['sei', 'seiest', 'sei', 'seien', 'seiet', 'seien'];
    const plusq = ['wäre', 'wärest', 'wäre', 'wären', 'wäret', 'wären'];
    for (final (i, MapEntry(key: pn, value: pron))
        in pronouns.entries.indexed) {
      expect(
        form('sitzen', 'konj.perf.akt.$pn').variants,
        contains('$pron gesessen ${perf[i]}'),
      );
      expect(
        form('sitzen', 'konj.plusq.akt.$pn').variants,
        contains('$pron gesessen ${plusq[i]}'),
      );
    }
  });

  for (final verb in ['lieben', 'töten']) {
    test('$verb gains no sein variant', () {
      expect(
        form(verb, 'konj.perf.akt.3.sg').variants!.any(sein.hasMatch),
        isFalse,
      );
    });
  }
}
