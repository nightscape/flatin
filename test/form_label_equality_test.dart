import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/form_label.dart';

import 'support/test_axes.dart';

Axes _caseNumberAxes({String secondCase = 'gen'}) => Axes(
  axes: [
    GrammarAxis(
      id: 'kasus',
      name: 'Kasus',
      values: [const ('nom', 'Nominativ'), (secondCase, 'Genitiv')],
    ),
    GrammarAxis(
      id: 'numerus',
      name: 'Numerus',
      values: const [('sg', 'Singular'), ('pl', 'Plural')],
    ),
  ],
  head: const [],
  tail: const ['kasus', 'numerus'],
  mergeAxis: 'kasus',
);

void main() {
  test('labels on the same Axes compare and hash by key', () {
    final a = nounLabel('nom', 'sg');
    final b = nounLabel('nom', 'sg');
    final other = nounLabel('gen', 'sg');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(other));
    expect({a, b, other}, hasLength(2));
  });

  test('hashCode ignores the Axes instance', () {
    final features = {'kasus': 'nom', 'numerus': 'sg'};
    final mine = FormLabel(features: features, axes: _caseNumberAxes());
    final foreign = FormLabel(features: features, axes: _caseNumberAxes());

    expect(identical(mine.axes, foreign.axes), isFalse);
    expect(mine.hashCode, foreign.hashCode);
  });

  test('comparing labels of two Axes instances is a programming error', () {
    final mine = nounLabel('nom', 'sg');
    final foreign = FormLabel(
      features: {'kasus': 'nom', 'numerus': 'sg'},
      axes: _caseNumberAxes(),
    );

    expect(() => mine == foreign, throwsA(isA<AssertionError>()));
  });

  test('Axes rejects a value code that two axes declare', () {
    expect(
      () => _caseNumberAxes(secondCase: 'sg'),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"sg"'),
        ),
      ),
    );
  });
}
