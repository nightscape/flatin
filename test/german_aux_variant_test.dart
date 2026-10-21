import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

const _path = 'lib/data/german_verbs.yaml';

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
}
