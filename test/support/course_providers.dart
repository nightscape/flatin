/// Seeding and curricula for the provider-level course tests.
library;

import 'dart:convert';

import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const practiceAssets = [
  'lib/data/latin_nouns.yaml',
  'lib/data/latin_verbs.yaml',
];

/// Starts the app's storage with [settings] as the stored settings.
void seedSettings(Settings settings) {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(settings.toJson()),
  });
}

/// Replaces the stored settings, leaving everything else in storage.
Future<void> storeSettings(Settings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('practice_settings', jsonEncode(settings.toJson()));
}

Future<Map<String, DataFileShape>> _shapes() async {
  final shapes = <String, DataFileShape>{};
  for (final path in practiceAssets) {
    final metadata = await getFormMetadata(path);
    shapes[metadata.dataFileId] = (
      labels: [
        for (final key in metadata.formOrder) metadata.formLabelsByKey[key]!,
      ],
      types: metadata.availableTypes,
    );
  }
  return shapes;
}

/// A curriculum over the real data that teaches everything in lesson 1 except
/// the Genitive, which it teaches in lesson 30: a narrowed range then has
/// forms on both sides of it.
Future<Curriculum> lateGenitiveCurriculum() async {
  final shapes = await _shapes();
  final yaml = StringBuffer('- lesson: 1\n');
  for (final file in shapes.entries) {
    yaml.writeln('  ${file.key}:');
    yaml.writeln('    forms:');
    yaml.writeln('      - {}');
    yaml.writeln('    types: [${file.value.types.join(', ')}]');
  }
  yaml.write('- lesson: 30\n  nouns:\n    forms:\n      - {kasus: gen}\n');
  return Curriculum.parse([yaml.toString()], shapes);
}

/// A curriculum over the real data that teaches everything in lesson 1 except
/// the type [typeName] of [dataFileId], which it teaches in [lesson].
Future<Curriculum> lateTypeCurriculum(
  String dataFileId,
  String typeName,
  int lesson,
) async {
  final shapes = await _shapes();
  final yaml = StringBuffer('- lesson: 1\n');
  for (final file in shapes.entries) {
    final types = [
      for (final type in file.value.types)
        if (!(file.key == dataFileId && type == typeName)) type,
    ];
    yaml.writeln('  ${file.key}:');
    yaml.writeln('    forms:');
    yaml.writeln('      - {}');
    yaml.writeln('    types: [${types.join(', ')}]');
  }
  yaml.write('- lesson: $lesson\n  $dataFileId:\n    types: [$typeName]\n');
  return Curriculum.parse([yaml.toString()], shapes);
}

/// A curriculum over the real data that teaches every type in lesson 1 and
/// every form of [dataFileId] in [lesson].
Future<Curriculum> lateFormsCurriculum(String dataFileId, int lesson) async {
  final shapes = await _shapes();
  final yaml = StringBuffer('- lesson: 1\n');
  for (final file in shapes.entries) {
    yaml.writeln('  ${file.key}:');
    if (file.key != dataFileId) {
      yaml.writeln('    forms:');
      yaml.writeln('      - {}');
    }
    yaml.writeln('    types: [${file.value.types.join(', ')}]');
  }
  yaml.write('- lesson: $lesson\n  $dataFileId:\n    forms:\n      - {}\n');
  return Curriculum.parse([yaml.toString()], shapes);
}
