import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';

void main() {
  test('each statement of the Rules section of EXAM_SCHEMA.md carries one '
      'rule id of the parser, and each rule id has one statement', () {
    final doc = File('lib/data/EXAM_SCHEMA.md').readAsStringSync();
    final rules = RegExp(
      r'^## Rules\n([\s\S]*?)(?:^## |(?![\s\S]))',
      multiLine: true,
    ).firstMatch(doc)![1]!;
    final statement = RegExp(r'^- \[(E-[a-z-]+)\] ');
    final bullets = [
      for (final line in rules.split('\n'))
        if (line.startsWith('- ')) line,
    ];
    expect([
      for (final b in bullets)
        if (!statement.hasMatch(b)) b,
    ], isEmpty);
    final ids = [for (final b in bullets) statement.firstMatch(b)![1]!];
    expect('[E-'.allMatches(doc).length, ids.length);
    expect(ids, unorderedEquals([for (final r in ExamRule.values) r.id]));
  });
}
