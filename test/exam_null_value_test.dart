import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';

void main() {
  test('a required field written without a value is refused as a pack', () {
    final source = File('test/fixtures/exam/synthetic.exam')
        .readAsStringSync()
        .replaceFirst('titel: Übungspack – Im Garten', 'titel:');
    expect(() => parseExam(source), throwsA(isA<ExamRejected>()));
  });
}
