import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'step_definitions/glossary.dart';
import 'support/i18n_keys.dart';

final _stringParam = RegExp(r'"([^"]*)"');

/// Every quoted phrase of every scenario that is not a key, a data word or a
/// picture/screen name must be in the glossary.
const _notTexts = {
  'home',
  'settings',
  'town',
  'points',
  'the word',
  'zzz',
  'templum',
  'argentaria',
  'domus, fons',
  'portus, bibliotheca, murus',
};

void main() {
  test('every glossary key exists in de.json and en.json', () {
    // Assures the phrase -> key map cannot point at a deleted key; the
    // scenarios would otherwise only fail inside the app.
    for (final code in ['de', 'en']) {
      final keys = translationKeys(code);
      for (final key in glossary.values) {
        expect(keys, contains(key), reason: '$key missing in $code.json');
      }
    }
  });

  test('every non-key phrase of the scenarios is in the glossary', () {
    // Assures that a new German phrase in a .feature file is caught here,
    // not only when the scenario runs.
    final phrases = {
      for (final f in Directory('test/features').listSync().whereType<File>())
        for (final m in _stringParam.allMatches(f.readAsStringSync()))
          m.group(1)!,
    };
    final texts = phrases.where(
      (p) =>
          !p.contains('.') &&
          !p.contains('_') &&
          !p.endsWith('.png') &&
          !_notTexts.contains(p) &&
          !p.contains('-'),
    );
    for (final phrase in texts) {
      expect(glossary, contains(phrase));
    }
    expect(glossary.keys.toSet().difference(phrases), isEmpty);
  });

  test('a phrase outside the glossary fails loud with the phrase', () {
    // Assures there is no fallback to the raw text.
    expect(
      () => glossaryKey('Synthetische Wendung'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Synthetische Wendung'),
        ),
      ),
    );
  });
}
