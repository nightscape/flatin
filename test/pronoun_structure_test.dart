// Pronoun paradigms are written out cell by cell, so no rule catches a wrong
// ending. Two facts hold inside every such paradigm and pin most of the cells
// against a one-gender typo.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

const _path = 'lib/data/latin_nouns.yaml';

/// Every pronoun lexeme that spells out a gendered paradigm.
const _coveredItemCount = 8;

/// A genitive plural ends in -rum or -ium; an enclitic (-dem) may follow, and
/// assimilates the preceding m to n.
final _genitivePlural = RegExp(r'(rum|ium)$|(run|iun)dem$');

final GrammarEngine _engine = GrammarEngine(
  parseGrammarFiles({_path: File(_path).readAsStringSync()}),
);

void main() {
  final items = _engine.files.single.items
      .where(
        (item) =>
            item.typeName.startsWith('Pronomen-') &&
            item.forms.containsKey('gen.sg.m'),
      )
      .toList();

  test('every gendered pronoun paradigm is covered', () {
    expect(items, hasLength(_coveredItemCount));
  });

  test('genitive and dative singular are equal across the genders', () {
    for (final item in items) {
      for (final feature in ['gen.sg', 'dat.sg']) {
        final masculine = item.forms['$feature.m'];
        expect(masculine, isNotNull, reason: '${item.id} $feature.m');
        for (final gender in ['f', 'n']) {
          expect(
            item.forms['$feature.$gender'],
            masculine,
            reason: '${item.id} $feature.$gender',
          );
        }
      }
    }
  });

  test('the genitive plural ends in -rum or -ium', () {
    for (final item in items.where(
      (item) => item.forms.containsKey('gen.pl.m'),
    )) {
      for (final gender in ['m', 'f', 'n']) {
        final forms = item.forms['gen.pl.$gender'];
        expect(forms, isNotNull, reason: '${item.id} gen.pl.$gender');
        for (final form in forms!) {
          expect(
            _genitivePlural.hasMatch(form),
            isTrue,
            reason: '${item.id} gen.pl.$gender: $form',
          );
        }
      }
    }
  });
}
