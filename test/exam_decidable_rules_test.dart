import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';

String _synthetic(String from, String to) {
  final source = File('test/fixtures/exam/synthetic.exam').readAsStringSync();
  expect(source, contains(from));
  return source.replaceFirst(from, to);
}

void main() {
  test('a passive esse token of a compound passive is refused', () {
    final source = _synthetic(
      'tempus: praes, modus: ind, genus_verbi: akt}, rolle: praedikat, '
          'verbform: [s2_4, s2_5]}',
      'tempus: praes, modus: ind, genus_verbi: pass}, rolle: praedikat, '
          'verbform: [s2_4, s2_5]}',
    );
    expect(() => parseExam(source), throwsA(isA<ExamRejected>()));
  });

  test('the PPP of a compound passive without kasus and genus is refused', () {
    final source = _synthetic(
      '{wortart: verb, kasus: nom, numerus: pl, genus: f, person: 3, '
          'tempus: perf',
      '{wortart: verb, numerus: pl, person: 3, tempus: perf',
    );
    expect(() => parseExam(source), throwsA(isA<ExamRejected>()));
  });

  test('a bilden form of a compound passive in one word is refused', () {
    final source = _synthetic('form: spectātae sunt', 'form: spectātae');
    expect(() => parseExam(source), throwsA(isA<ExamRejected>()));
  });

  test('EXAM_SCHEMA.md states no rule that the parser does not check', () {
    final doc = File('lib/data/EXAM_SCHEMA.md').readAsStringSync();
    expect(doc, isNot(contains('not checked')));
  });
}
