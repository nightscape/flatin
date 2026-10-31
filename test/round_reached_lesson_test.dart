import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

void main() {
  final table = [
    (words: LessonRange(1, 25), grammar: null, reached: 25),
    (words: LessonRange(1, 30), grammar: LessonRange(1, 20), reached: 20),
    (words: LessonRange(1, 10), grammar: LessonRange(1, 20), reached: 10),
    (words: LessonRange(5, 25), grammar: LessonRange(3, 25), reached: 25),
    (words: LessonRange.full, grammar: LessonRange(1, 12), reached: 12),
    (words: LessonRange(1, 12), grammar: LessonRange.full, reached: 12),
    (words: LessonRange.full, grammar: LessonRange.full, reached: laterLesson),
    (words: LessonRange(1, 1), grammar: null, reached: 1),
  ];
  for (final (:words, :grammar, :reached) in table) {
    test('words $words, grammar ${grammar ?? 'linked'}: the reached lesson is '
        '$reached', () {
      final settings = Settings(
        courseWords: words,
        courseGrammar: grammar,
        grammarToLinked: grammar == null,
      );
      expect(reachedLesson(settings), reached);
    });
  }
}
