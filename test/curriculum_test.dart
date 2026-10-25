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
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 5
  nouns:
    forms:
      - {name: T, kasus: dat}
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
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 7
  nouns:
    forms:
      - {name: T, kasus: [dat, abl]}
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
      - {name: T, kasus: nom}
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
      - {name: T}
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
      - {name: T}
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
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 4
  nouns:
    forms:
      - {name: T, kasus: dat}
- lesson: 9
  nouns:
    forms:
      - {name: T, numerus: pl}
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

  test('an interleaved more specific selector does not hide a conflict', () {
    const entries = [
      '''
- lesson: 1
  nouns:
    forms:
      - {name: T}
    types: [A-Deklination, O-Deklination]
''',
      '''
- lesson: 4
  nouns:
    forms:
      - {name: T, kasus: dat}
''',
      '''
- lesson: 7
  nouns:
    forms:
      - {name: T, kasus: dat, numerus: pl}
''',
      '''
- lesson: 9
  nouns:
    forms:
      - {name: T, numerus: pl}
''',
    ];
    final conflict = throwsA(
      isStateError.having(
        (e) => e.message,
        'message',
        allOf(contains('dat.pl'), contains('equally')),
      ),
    );

    final orders = permutations(entries).toList();
    expect(orders, hasLength(24));
    for (final order in orders) {
      expect(
        () => parseNouns(order.join()),
        conflict,
        reason: order
            .map((e) => RegExp(r'lesson: (\d+)').firstMatch(e)![1])
            .join(' '),
      );
    }
  });

  test('two equally specific selectors of the same lesson are fine', () {
    final curriculum = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 4
  nouns:
    forms:
      - {name: T, kasus: dat}
      - {name: T, numerus: pl}
''');

    expect(curriculum.formLesson('nouns', nounLabel('dat', 'pl').key), 4);
  });

  test('a selector naming an unknown axis is a load error', () {
    expect(
      () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {name: T, tempus: praes}
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
      - {name: T, kasus: lok}
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
      - {name: T}
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
      - {name: T}
    types: [A-Deklination, O-Deklination]
'''),
        throwsA(
          isStateError.having((e) => e.message, 'message', contains('outside')),
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
      - {name: T}
    types: [A-Deklination]
- lesson: 12
  nouns:
    types: [O-Deklination]
''');

    expect(
      curriculum.taughtForm(
        'nouns',
        nounLabel('nom', 'sg').key,
        LessonRange(1, 5),
      ),
      isTrue,
    );
    expect(
      curriculum.taughtForm(
        'nouns',
        nounLabel('nom', 'sg').key,
        LessonRange(1, 2),
      ),
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

  for (final entry in ['{kasus: dat}', '{name: "", kasus: dat}']) {
    test('a forms entry $entry without a name is a load error', () {
      expect(
        () => parseNouns('''
- lesson: 1
  nouns:
    forms:
      - $entry
    types: [A-Deklination, O-Deklination]
'''),
        throwsA(isA<StateError>()),
      );
    });
  }

  test('the name is not part of the stored key', () {
    final named = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {name: T}
      - {name: Dativ, kasus: dat}
    types: [A-Deklination, O-Deklination]
''');
    final other = parseNouns('''
- lesson: 1
  nouns:
    forms:
      - {name: T}
      - {name: Anders, kasus: dat}
    types: [A-Deklination, O-Deklination]
''');
    expect(
      [for (final t in named.courseTopics) t.key],
      [for (final t in other.courseTopics) t.key],
    );
  });
}
