// The gendered numerals spell out every cell, so no rule catches a wrong
// ending. Where the language shares a cell between genders the paradigm must
// repeat it, and that pins most cells against a one-gender typo.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

const _path = 'lib/data/latin_nouns.yaml';

/// Every numeral that spells out a gendered paradigm.
const _genderedItemCount = 3;

/// Of those, the ones declined in the singular, and the ones in the plural.
const _singularItemCount = 1;
const _pluralItemCount = 2;

/// A genitive plural ends in -rum or -ium.
final _genitivePlural = RegExp(r'(rum|ium)$');

/// Plural numerals whose feminine nominative equals the masculine one.
const _sharedNominativePlural = {'tres'};

/// Plural cases that the feminine spells like the masculine.
const _genderSharedPluralCases = <String>{};
final GrammarEngine _engine = GrammarEngine(
  parseGrammarFiles({_path: File(_path).readAsStringSync()}),
);

void main() {
  final items = _engine.files.single.items
      .where(
        (item) =>
            item.typeName.startsWith('Numerale-') &&
            item.forms.keys.any((feature) => feature.endsWith('.m')),
      )
      .toList();

  final singulars = items
      .where((item) => item.forms.containsKey('gen.sg.m'))
      .toList();
  final plurals = items
      .where((item) => item.forms.containsKey('gen.pl.m'))
      .toList();

  test('every gendered numeral paradigm is covered', () {
    expect(items, hasLength(_genderedItemCount));
    expect(singulars, hasLength(_singularItemCount));
    expect(plurals, hasLength(_pluralItemCount));
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

  test('masculine and neuter share the oblique cells', () {
    for (final item in items) {
      for (final number in ['sg', 'pl']) {
        for (final kasus in ['gen', 'dat', 'abl']) {
          final masculine = item.forms['$kasus.$number.m'];
          if (masculine == null) continue;
          expect(
            item.forms['$kasus.$number.n'],
            masculine,
            reason: '${item.id} $kasus.$number.n',
          );
        }
      }
    }
  });

  test('genitive and dative singular are equal across the genders', () {
    for (final item in singulars) {
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

  test('dative and ablative plural are equal within each gender', () {
    for (final item in plurals) {
      for (final gender in ['m', 'f', 'n']) {
        final dative = item.forms['dat.pl.$gender'];
        expect(dative, isNotNull, reason: '${item.id} dat.pl.$gender');
        expect(
          item.forms['abl.pl.$gender'],
          dative,
          reason: '${item.id} abl.pl.$gender',
        );
      }
    }
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

  test('only trēs shares the nominative plural across genders', () {
    for (final item in plurals) {
      expect(
        item.forms['nom.pl.f'],
        _sharedNominativePlural.contains(item.id)
            ? item.forms['nom.pl.m']
            : isNot(item.forms['nom.pl.m']),
        reason: '${item.id} nom.pl.f',
      );
    }
  });

  test('the plural oblique cells keep the feminine stem', () {
    for (final item in plurals) {
      if (_sharedNominativePlural.contains(item.id)) continue;
      for (final kasus in ['gen', 'dat', 'akk', 'abl']) {
        final masculine = item.forms['$kasus.pl.m'];
        expect(
          item.forms['$kasus.pl.f'],
          _genderSharedPluralCases.contains(kasus)
              ? masculine
              : isNot(masculine),
          reason: '${item.id} $kasus.pl.f',
        );
      }
    }
  });
}
