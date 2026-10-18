import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/course_fixture.dart';
import 'support/test_axes.dart';

void main() {
  test('the most specific selector wins', () {
    final curriculum = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 5
  nouns:
    forms:
      - {kasus: dat}
''');

    expect(curriculum.formLesson('nouns', nounLabel('dat', 'pl').key), 5);
    expect(curriculum.formLesson('nouns', nounLabel('nom', 'sg').key), 1);
    expect(curriculum.formLesson('nouns', nounLabel('abl', 'pl').key), 1);
  });

  test('a selector accepts a list of codes', () {
    final curriculum = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 7
  nouns:
    forms:
      - {kasus: [dat, abl]}
''');

    expect(curriculum.formLesson('nouns', nounLabel('dat', 'pl').key), 7);
    expect(curriculum.formLesson('nouns', nounLabel('abl', 'pl').key), 7);
    expect(curriculum.formLesson('nouns', nounLabel('gen', 'sg').key), 1);
  });

  test('a form no selector matches is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {kasus: nom}
    types: [A-Deklination, O-Deklination]
'''),
      throwsA(
        isStateError.having((e) => e.message, 'message', contains('gen.sg')),
      ),
    );
  });

  test('a type no lesson teaches is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination]
'''),
      throwsA(
        isStateError.having(
          (e) => e.message,
          'message',
          contains('O-Deklination'),
        ),
      ),
    );
  });

  test('a type two lessons teach is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 4
  nouns:
    types: [A-Deklination]
'''),
      throwsA(
        isStateError.having((e) => e.message, 'message', contains('twice')),
      ),
    );
  });

  test('two equally specific selectors of different lessons conflict', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 4
  nouns:
    forms:
      - {kasus: dat}
- lesson: 9
  nouns:
    forms:
      - {numerus: pl}
'''),
      throwsA(
        isStateError.having(
          (e) => e.message,
          'message',
          allOf(contains('dat.pl'), contains('equally')),
        ),
      ),
    );
  });

  test('two equally specific selectors of the same lesson are fine', () {
    final curriculum = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 4
  nouns:
    forms:
      - {kasus: dat}
      - {numerus: pl}
''');

    expect(curriculum.formLesson('nouns', nounLabel('dat', 'pl').key), 4);
  });

  test('a selector naming an unknown axis is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {tempus: praes}
    types: [A-Deklination, O-Deklination]
'''),
      throwsA(
        isStateError.having((e) => e.message, 'message', contains('tempus')),
      ),
    );
  });

  test('a selector naming an unknown code is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {kasus: lok}
    types: [A-Deklination, O-Deklination]
'''),
      throwsA(
        isStateError.having((e) => e.message, 'message', contains('lok')),
      ),
    );
  });

  test('a type no data file has is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination, U-Deklination]
'''),
      throwsA(
        isStateError.having(
          (e) => e.message,
          'message',
          contains('U-Deklination'),
        ),
      ),
    );
  });

  test('a lesson outside 1..lastLesson is a load error', () {
    for (final lesson in [0, 41]) {
      expect(
        () => parseNouns('''
- lesson: $lesson
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
'''),
        throwsA(
          isStateError.having(
            (e) => e.message,
            'message',
            contains('outside'),
          ),
        ),
        reason: 'lesson $lesson',
      );
    }
  });

  test('taught* answers against a range', () {
    final curriculum = parseNouns('''
- lesson: 3
  nouns:
    forms:
      - {}
    types: [A-Deklination]
- lesson: 12
  nouns:
    types: [O-Deklination]
''');

    expect(
      curriculum.taughtForm('nouns', nounLabel('nom', 'sg').key,
          LessonRange(1, 5)),
      isTrue,
    );
    expect(
      curriculum.taughtForm('nouns', nounLabel('nom', 'sg').key,
          LessonRange(1, 2)),
      isFalse,
    );
    expect(
      curriculum.taughtType('nouns', 'O-Deklination', LessonRange(1, 11)),
      isFalse,
    );
    expect(
      curriculum.taughtType('nouns', 'O-Deklination', LessonRange(1, 12)),
      isTrue,
    );
  });
}
