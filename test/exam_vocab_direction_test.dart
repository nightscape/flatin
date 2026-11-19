import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/exam_conversion.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_exam.dart';

final _en = Language.parse(
  File('lib/data/languages/en.yaml').readAsStringSync(),
);

Map<String, dynamic> _copy(Object pack) =>
    jsonDecode(jsonEncode(pack)) as Map<String, dynamic>;

/// [pack] with the `direction` of its vocab task [i] removed, and the path
/// that a refusal names; null when the pack has no vocab task.
(Map<String, dynamic>, String)? vocabWithoutDirection(
  Map<String, dynamic> pack,
  Random r,
) {
  final tasks = pack['tasks'] as List;
  final vocab = [
    for (final (i, t) in tasks.indexed)
      if ((t as Map)['type'] == 'vocab') i,
  ];
  if (vocab.isEmpty) return null;
  final i = vocab[r.nextInt(vocab.length)];
  (tasks[i] as Map).remove('direction');
  return (pack, 'exam.tasks[$i]');
}

List<String> _errors(Map<String, dynamic> pack, Language language) {
  try {
    parseExam(jsonEncode(pack), language);
    return [];
  } on ExamRejected catch (e) {
    return [for (final x in e.errors) '${x.rule.id} ${x.path}'];
  }
}

void main() {
  test('a vocab task without direction is refused at the task', () {
    final cases = <(String, Map<String, dynamic>, Language)>[
      (
        'Latin fixture',
        _copy(
          convertSchema1(
            _copy(
              loadYaml(
                File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
              ),
            ),
          ),
        ),
        latinLang,
      ),
      for (var seed = 0; seed < 50; seed++)
        (
          'English seed $seed',
          _copy(
            EnglishExamGen(
              Random(seed),
            ).exam(include: {...EnglishExamGen.kinds}),
          ),
          _en,
        ),
    ];
    var reached = 0;
    for (final (i, (name, pack, language)) in cases.indexed) {
      final hit = vocabWithoutDirection(pack, Random(i));
      if (hit == null) continue;
      reached++;
      final (broken, path) = hit;
      expect(
        _errors(broken, language),
        contains('E-field $path'),
        reason: name,
      );
    }
    expect(reached, greaterThan(1));
  });
}
