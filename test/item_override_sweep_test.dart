// Every item override in the data must be a correction. I4 drops an override
// that repeats the rule-generated form; a macron is part of the form, so only
// a character-for-character repetition counts as a repetition.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';

const _paths = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

final GrammarEngine _engine = GrammarEngine(
  parseGrammarFiles({
    for (final path in _paths) path: File(path).readAsStringSync(),
  }),
);

void main() {
  test('every item override is applied and none repeats the rule', () {
    final dead = <String>[];
    final dropped = <String>[];
    for (final file in _engine.files) {
      for (final item in file.items) {
        final derivation = _engine.of(file.dataFileId, item.id);
        for (final entry in item.forms.entries) {
          final where = '${item.id} ${entry.key}';
          final form =
              derivation.forms[entry.key] ?? derivation.internal[entry.key];
          if (form is! IrregularForm) {
            dropped.add('$where: ${entry.value.join(" / ")}');
            continue;
          }
          final regular = form.regular;
          if (regular != null && _same(regular.variants, entry.value)) {
            dead.add('$where: ${entry.value.join(" / ")}');
          }
        }
      }
    }
    expect(dropped, isEmpty, reason: 'override not applied');
    expect(dead, isEmpty, reason: 'override repeats the rule');
  });

  test('a quantity-only override wins over the rule', () {
    final adverb = _engine.of('nouns', 'malus').forms['adv.pos']!;
    expect(adverb.result, 'male');
    expect((adverb as IrregularForm).regular!.result, 'malē');
  });
}

bool _same(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
