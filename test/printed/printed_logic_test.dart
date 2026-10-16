import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'printed.dart';

PrintedResult compare(String yaml) {
  final printed = parsePrinted(yaml);
  final ours = engineOf([
    for (final l in printed) l.id,
  ], (path) => File(path).readAsStringSync());
  return comparePrinted(
    printed: printed,
    engine: ours.items,
    axesByFile: ours.axes,
  );
}

String lemma(String name, String features, String spelling) =>
    '''
- lemma: $name
  forms:
  - {features: $features, spellings: [$spelling]}
''';

void main() {
  const noun = '{kasus: nom, numerus: sg}';

  test('a form of ours that is one of the spellings is no finding', () {
    final r = compare(lemma('dominus', noun, 'dominus'));
    expect([r.compared, r.diffs, r.missing], [1, isEmpty, isEmpty]);
  });

  test('a macron counts', () {
    final r = compare(lemma('dominus', noun, 'dominūs'));
    expect(r.diffs.single.describe, 'dominus nom.sg engine: dominus');
  });

  test('a feature set without a form of ours is missing', () {
    final r = compare(
      lemma(
        'ferre',
        '{modus: ind, tempus: praes, genus_verbi: pass, person: 1, numerus: sg}',
        'feror',
      ),
    );
    expect(r.missing.single.describe, 'ferre ind.praes.pass.1.sg (missing)');
  });

  test('the perfect passive of ours is the masculine only', () {
    const features =
        '{modus: ind, tempus: perf, genus_verbi: pass, person: 1, numerus: sg, genus: ';
    expect(
      compare(lemma('vocāre', '${features}m}', 'vocātus sum')).diffs,
      isEmpty,
    );
    final f = compare(lemma('vocāre', '${features}f}', 'vocāta sum'));
    expect(f.missing.single.features, 'ind.perf.pass.1.sg.f');
  });

  test('a feature set without a mapping is refused', () {
    expect(
      () => compare(lemma('dominus', '{modus: ind}', 'x')),
      throwsA(
        isA<StateError>().having(
          (e) => '$e',
          'message',
          contains('dominus ind'),
        ),
      ),
    );
  });

  test('a lemma without an item is listed as unmatched', () {
    final r = compare(lemma('nonexistens', noun, 'x'));
    expect(
      [r.matched, r.unmatched],
      [
        isEmpty,
        ['nonexistens'],
      ],
    );
  });

  group('allowed.yaml', () {
    final r = compare(lemma('dominus', noun, 'dominūs'));
    Allowed allowed(String diffs) =>
        Allowed.parse('matched_lemmas: 1\ndiffs: [$diffs]\nmissing: []\n');

    test('lists a finding to make it pass', () {
      final a = allowed(
        '{lemma: dominus, features: [nom.sg], engine: dominus, reason: x}',
      );
      expect([r.unlisted(a), r.stale(a)], [isEmpty, isEmpty]);
    });

    test('is red without the entry', () {
      expect(r.unlisted(allowed('')), hasLength(1));
    });

    test('is red for an entry that matches nothing', () {
      final a = allowed(
        '{lemma: dominus, features: [nom.sg, gen.sg], engine: dominus, reason: x}',
      );
      expect(r.stale(a), ['dominus gen.sg']);
    });

    test('is red for an entry whose engine form changed', () {
      final a = allowed(
        '{lemma: dominus, features: [nom.sg], engine: dominī, reason: x}',
      );
      expect([r.unlisted(a), r.stale(a)], [hasLength(1), hasLength(1)]);
    });
  });
}
