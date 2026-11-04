// Checks `.exam` packs: prints `<argument index> OK` or one
// `<argument index> <rule id> <path>` line per error, and never pack text.
import 'dart:io';

import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

void main(List<String> paths) {
  final course =
      (loadYaml(File('lib/data/courses.yaml').readAsStringSync()) as YamlList)
              .single
          as String;
  final language =
      (loadYaml(File(course).readAsStringSync()) as YamlMap)['language'];
  final latin = Language.parse(File(language as String).readAsStringSync());
  for (final (i, path) in paths.indexed) {
    try {
      parseExam(File(path).readAsStringSync(), latin);
      stdout.writeln('$i OK');
    } on ExamRejected catch (e) {
      for (final error in e.errors) {
        stdout.writeln('$i ${error.rule.id} ${error.path}');
      }
    }
  }
}
