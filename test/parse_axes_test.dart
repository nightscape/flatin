import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:yaml/yaml.dart';

YamlMap _read(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in const [
    'lib/data/latin_nouns.yaml',
    'lib/data/latin_verbs.yaml',
  ]) {
    test('$path passes the axes and label checks of the schema', () async {
      final axes = parseAxes(_read(path), path: path);
      final metadata = await getFormMetadata(path);

      expect(metadata.formOrder, isNotEmpty);
      for (final key in metadata.formOrder) {
        final label = metadata.formLabelsByKey[key]!;
        expect(label.key, key);
        expect(axes.parseKey(key), label.features);
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
