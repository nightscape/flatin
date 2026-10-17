import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'oracle.dart';
import 'sample.dart';

Sample _sampleOf(Map<String, int> lemmas) => Sample(const {}, const [], lemmas);

void main() {
  late TypeMap shipped;

  setUpAll(() {
    shipped = TypeMap.parse(
      File('test/oracle/type_map.yaml').readAsStringSync(),
    );
  });

  TypeMap map(String models) => TypeMap.parse(
    'sample: {}\nshipped: {}\nmodels:\n$models\nspelling: {}\n',
  );

  group('the lemma floor', () {
    test('a declared count of 0 is refused', () {
      final zero = map(
        '  x: {types: [X], lemmas: 0, noun: {cut: 0, genitive: is}}',
      );
      expect(
        () => modelsOffFloor([
          _sampleOf({'x': 0}),
        ], zero),
        throwsStateError,
      );
    });

    test('a declared count at or above the floor is refused', () {
      final high = map(
        '  x: {types: [X], lemmas: $lemmasPerModel, noun: {cut: 0, genitive: is}}',
      );
      expect(
        () => modelsOffFloor([
          _sampleOf({'x': 0}),
        ], high),
        throwsStateError,
      );
    });

    test('a sample that drops a model below the floor names that model', () {
      final atFloor = {
        for (final e in shipped.builds.entries)
          e.key: e.value.lemmas ?? lemmasPerModel,
      };
      expect(modelsOffFloor([_sampleOf(atFloor)], shipped), isEmpty);
      expect(
        modelsOffFloor([
          _sampleOf({...atFloor, 'lupus': 3}),
        ], shipped),
        {'lupus': 3},
      );
    });

    test('a model sampled by two corpora is not counted twice', () {
      final atFloor = {
        for (final e in shipped.builds.entries)
          e.key: e.value.lemmas ?? lemmasPerModel,
      };
      expect(
        modelsOffFloor([_sampleOf(atFloor), _sampleOf(atFloor)], shipped),
        isEmpty,
      );
    });
  });

  group('type_map.yaml is refused when', () {
    test('a model without a build kind declares lemmas', () {
      expect(() => map('  x: {types: [X], lemmas: 5}'), throwsFormatException);
    });

    test('a model has two build kinds', () {
      expect(
        () => map('  x: {types: [X], verb: {strip: o}, noun: {cut: 0}}'),
        throwsFormatException,
      );
    });

    test('a model has a key it does not know', () {
      expect(() => map('  x: {types: [X], stray: 1}'), throwsFormatException);
    });

    test('a build kind has no build', () {
      expect(() => map('  x: {types: [X], verb: null}'), throwsFormatException);
    });
  });
}
