import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/hand_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a unit name carries its lesson number', () {
    expect(lessonNumber('Lektion 22 Stammformen'), 22);
    expect(lessonNumber('Lektion 1'), 1);
    expect(lessonNumber('Plateaulektion 11 – 15 Stammformen'), 11);
    expect(() => lessonNumber('Anhang'), throwsStateError);
  });

  test('every unit name of the data carries a lesson number', () async {
    final lessons = await loadLessonData(lessonDataAssets);

    expect(lessons.lessonNames, hasLength(73));
    for (final name in lessons.lessonNames) {
      expect(lessonNumber(name), inInclusiveRange(1, lastLesson), reason: name);
    }
  });

  test('the lesson scale runs 1..lastLesson, split over two volumes',
      () async {
    final lessons = await loadLessonData(lessonDataAssets);

    expect(lessons.lessonNumbers, [for (var i = 1; i <= lastLesson; i++) i]);
    expect(lessons.bookOf(20), 1);
    expect(lessons.bookOf(21), 2);
  });

  test('every practice item belongs to a lesson', () async {
    final lessons = await loadLessonData(lessonDataAssets);
    final items = await loadAllPracticeItems();

    assertLessonsCoverItems(lessons, items);
    for (final item in items) {
      expect(
        lessons.lessonNumberOf(item),
        inInclusiveRange(1, lastLesson),
        reason: item.id,
      );
    }
  });

  test('an item no lesson introduces is named', () {
    const lessons = LessonData(
      lessonNames: ['Lektion 1'],
      wordToLesson: {'amāre': 'Lektion 1'},
      lessonWords: {
        'Lektion 1': ['amāre'],
      },
      bookByLesson: {1: 1},
    );
    final orphan = handItem(
      dataFileId: 'verbs',
      lemma: 'vagārī',
      axes: fullVerbAxes,
      forms: {
        'ind.praes.akt.3.sg': ['vagātur'],
      },
    );

    expect(() => lessons.lessonNumberOf(orphan), throwsStateError);
    expect(
      () => assertLessonsCoverItems(lessons, [orphan]),
      throwsA(
        isStateError.having((e) => e.message, 'message', contains('vagārī')),
      ),
    );
  });

  test('a lesson range covers its lessons and survives a JSON round trip', () {
    final range = LessonRange(3, 7);

    expect(range.contains(3), isTrue);
    expect(range.contains(7), isTrue);
    expect(range.contains(2), isFalse);
    expect(range.contains(8), isFalse);
    expect(LessonRange.fromJson(range.toJson()), range);
    expect(LessonRange.full, LessonRange(1, lastLesson));
  });

  test('a lesson range outside the scale is a programming error', () {
    expect(() => LessonRange(0, 5), throwsA(isA<AssertionError>()));
    expect(() => LessonRange(5, 3), throwsA(isA<AssertionError>()));
    expect(
      () => LessonRange(1, lastLesson + 1),
      throwsA(isA<AssertionError>()),
    );
  });
}
