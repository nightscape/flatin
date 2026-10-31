import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

void main() {
  for (final kursstand in [1, 12, 25, lastLesson]) {
    test('the reached lesson is the Kursstand $kursstand, whatever the course '
        'ranges', () {
      final settings = Settings(
        courseWords: LessonRange(1, 10),
        courseGrammar: LessonRange(1, 30),
        grammarToLinked: false,
        kursstand: kursstand,
      );
      expect(reachedLesson(settings), kursstand);
    });
  }

  final table = [
    (words: LessonRange(1, 25), grammar: null, reached: 25),
    (words: LessonRange(1, 30), grammar: LessonRange(1, 20), reached: 30),
    (words: LessonRange(1, 10), grammar: LessonRange(1, 20), reached: 20),
    (words: LessonRange(5, 25), grammar: LessonRange(3, 25), reached: 25),
    (words: LessonRange.full, grammar: LessonRange(1, 12), reached: lastLesson),
    (words: LessonRange(1, 12), grammar: LessonRange.full, reached: lastLesson),
    (words: LessonRange.full, grammar: LessonRange.full, reached: lastLesson),
    (words: LessonRange(1, 1), grammar: null, reached: 1),
  ];
  for (final (:words, :grammar, :reached) in table) {
    test('without a Kursstand, words $words and grammar '
        '${grammar ?? 'linked'} reach lesson $reached', () {
      final settings = Settings(
        courseWords: words,
        courseGrammar: grammar,
        grammarToLinked: grammar == null,
      );
      expect(reachedLesson(settings), reached);
    });
  }
}
