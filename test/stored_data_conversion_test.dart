import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';

void main() {
  final map = MigrationMap.parse(
    File('lib/data/migration_v2.yaml').readAsStringSync(),
  );

  Set<String> forms(Map<String, dynamic> json, String file) =>
      Set<String>.from(json['disabledForms'][file] as List);
  Set<String> types(Map<String, dynamic> json, String file) =>
      Set<String>.from(json['disabledTypes'][file] as List);

  test('the oldest format stores what was enabled', () {
    final converted = convertSettingsV2({
      'enabledForms': {
        'nouns': ['nominative_singular', 'genitive_singular'],
      },
      'enabledTypes': {
        'nouns': ['A-Deklination'],
      },
    }, map);

    expect(converted['settingsVersion'], 2);
    expect(forms(converted, 'nouns'), isNot(contains('nom.sg')));
    expect(forms(converted, 'nouns'), contains('dat.sg'));
    expect(forms(converted, 'nouns'), contains('dat.sg.m'));
    expect(types(converted, 'nouns'), contains('O-Deklination-maskulinum'));
    expect(types(converted, 'nouns'), isNot(contains('A-Deklination')));
    // A file the stored settings say nothing about stays untouched.
    expect(forms(converted, 'verbs'), isEmpty);
    expect(converted, isNot(contains('enabledForms')));
  });

  test('the disabled-set format is read key by key', () {
    final converted = convertSettingsV2({
      'disabledForms': {
        'nouns': ['vocative_singular', 'vocative_plural'],
        'verbs': ['imperativ_singular'],
      },
      'disabledTypes': {
        'verbs': ['K-Konjugation'],
      },
      'inputStrategyIds': {'verbs': 'dropdown_all_forms'},
      'deselectedWords': ['regis', 'ea'],
    }, map);

    expect(forms(converted, 'nouns'), {'vok.sg', 'vok.pl'});
    expect(forms(converted, 'verbs'), {'imp.praes.akt.2.sg'});
    expect(types(converted, 'verbs'), {'Konsonantische'});
    expect(converted['inputStrategyIds'], {'verbs': 'dropdown_all_forms'});
    // "regis" is renamed, "ea" is only part of the merged pronoun.
    expect(converted['deselectedWords'], ['rex']);
  });

  test('an unknown entry is dropped', () {
    final converted = convertSettingsV2({
      'disabledForms': {
        'nouns': ['nominative_singular', 'lokativ_singular'],
      },
      'deselectedWords': ['rosa'],
    }, map);

    expect(forms(converted, 'nouns'), contains('nom.sg'));
    expect(
      forms(converted, 'nouns').where((k) => k.startsWith('lokativ')),
      isEmpty,
    );
    // A word of an item that is not renamed stays as it is.
    expect(converted['deselectedWords'], ['rosa']);
  });

  test('a merged type is disabled only if all its old types were', () {
    final partly = convertSettingsV2({
      'disabledForms': <String, dynamic>{},
      'disabledTypes': {
        'verbs': ['E-Konjugation', 'E-Konjugation (s-Perfekt)'],
      },
    }, map);
    expect(types(partly, 'verbs'), isEmpty);

    final fully = convertSettingsV2({
      'disabledForms': <String, dynamic>{},
      'disabledTypes': {
        'verbs': [
          'E-Konjugation',
          'E-Konjugation (s-Perfekt)',
          'E-Konjugation (Stammperfekt)',
        ],
      },
    }, map);
    expect(types(fully, 'verbs'), {'E-Konjugation'});
  });

  test('a merged item is deselected only if all its old items were', () {
    final partly = convertSettingsV2({
      'disabledForms': <String, dynamic>{},
      'deselectedWords': ['is', 'ea'],
    }, map);
    expect(partly['deselectedWords'], isEmpty);

    final fully = convertSettingsV2({
      'disabledForms': <String, dynamic>{},
      'deselectedWords': ['is', 'ea', 'id'],
    }, map);
    expect(fully['deselectedWords'], ['is']);
  });

  test('converted settings are left alone', () {
    final once = convertSettingsV2({
      'disabledForms': {
        'nouns': ['nominative_singular'],
      },
      'disabledTypes': {
        'verbs': ['E-Konjugation'],
      },
    }, map);
    expect(convertSettingsV2(once, map), same(once));
  });

  test('a form the old settings screen never offered stays practised', () {
    // `form_order` of the old nouns file: what the settings screen offered.
    // The vocative is NOT in it, so no stored v0 set can ever contain it.
    const offered = [
      'nominative_singular',
      'genitive_singular',
      'dative_singular',
      'accusative_singular',
      'ablative_singular',
      'nominative_plural',
      'genitive_plural',
      'dative_plural',
      'accusative_plural',
      'ablative_plural',
    ];
    final converted = convertSettingsV2({
      'enabledForms': {'nouns': offered},
    }, map);

    // The user switched nothing off, so nothing is disabled; the vocative is
    // new in v2 and is practised by default (Settings doc comment).
    expect(forms(converted, 'nouns'), isEmpty);
  });
}
