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

/// Of those, the ones that spell out a plural.
const _pluralItemCount = 7;

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

  test('every number present spells out every case in every gender', () {
    for (final item in items) {
      for (final number in ['sg', 'pl']) {
        if (!item.forms.keys.any((feature) => feature.contains('.$number.'))) {
          continue;
        }
        for (final kasus in ['nom', 'gen', 'dat', 'akk', 'abl']) {
          for (final gender in ['m', 'f', 'n']) {
            expect(
              item.forms['$kasus.$number.$gender'],
              isNotNull,
              reason: '${item.id} $kasus.$number.$gender',
            );
          }
        }
      }
    }
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

  final plurals = items
      .where((item) => item.forms.containsKey('gen.pl.m'))
      .toList();

  test('every gendered pronoun paradigm with a plural is covered', () {
    expect(plurals, hasLength(_pluralItemCount));
  });

  test('the genitive plural ends in -rum or -ium', () {
    for (final item in plurals) {
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

  test('the genitive plural differs by gender where the nominative does', () {
    for (final item in plurals) {
      String nominative(String gender) =>
          item.forms['nom.pl.$gender']!.join('/');
      if (nominative('f') == nominative('m')) continue;
      expect(
        item.forms['gen.pl.f'],
        isNot(item.forms['gen.pl.m']),
        reason: '${item.id} gen.pl.f',
      );
    }
  });
}
