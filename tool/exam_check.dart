// Checks `.exam` packs: prints `<argument index> OK` or one
// `<argument index> <rule id> <path>` line per error, and never pack text.
// A pack is checked with the language of the course it names, else of the
// first course.
import 'dart:io';

import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

void main(List<String> paths) {
  final courses = [
    for (final file
        in loadYaml(File('lib/data/courses.yaml').readAsStringSync())
            as YamlList)
      loadYaml(File(file as String).readAsStringSync()) as YamlMap,
  ];
  for (final (i, path) in paths.indexed) {
    final source = File(path).readAsStringSync();
    final named = (loadYaml(source) as YamlMap)['course'];
    final course = named == null
        ? courses.first
        : courses.firstWhere((c) => c['id'] == named);
    final language = Language.parse(
      File(course['language'] as String).readAsStringSync(),
    );
    try {
      parseExam(source, language);
      stdout.writeln('$i OK');
    } on ExamRejected catch (e) {
      for (final error in e.errors) {
        stdout.writeln('$i ${error.rule.id} ${error.path}');
      }
    }
  }
}
