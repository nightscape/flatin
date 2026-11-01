// Checks `.exam` packs: prints `<argument index> OK` or one
// `<argument index> <rule id> <path>` line per error, and never pack text.
import 'dart:io';

import 'package:latin_practice/data/exam.dart';

void main(List<String> paths) {
  for (final (i, path) in paths.indexed) {
    try {
      parseExam(File(path).readAsStringSync());
      stdout.writeln('$i OK');
    } on ExamRejected catch (e) {
      for (final error in e.errors) {
        stdout.writeln('$i ${error.rule.id} ${error.path}');
      }
    }
  }
}
