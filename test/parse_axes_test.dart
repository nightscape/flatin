import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/form_label.dart';
import 'package:yaml/yaml.dart';

YamlMap _read(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

void main() {
  for (final path in const [
    'lib/data/latin_nouns.yaml',
    'lib/data/latin_verbs.yaml',
  ]) {
    test('$path passes the axes and label checks of the schema', () {
      final root = _read(path);
      final axes = parseAxes(root, path: path);

      final labels = (root['form_labels'] as YamlMap).map(
        (key, value) => MapEntry(
          '$key',
          FormLabel(
            features: {
              for (final feature in (value as YamlMap).entries)
                '${feature.key}': '${feature.value}',
            },
            axes: axes,
          ),
        ),
      );

      expect(labels, isNotEmpty);
      for (final label in labels.values) {
        expect(axes.parseKey(label.key), label.features);
        expect(label.displayName, isNotEmpty);
      }
    });
  }

  test('S1: a code declared by two axes is rejected', () {
    final root = _read('test/data/duplicate_code.yaml');
    expect(
      () => parseAxes(root, path: 'test/data/duplicate_code.yaml'),
      throwsA(isA<SchemaError>()),
    );
  });
}
