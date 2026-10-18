import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart' show lastLesson;
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

void main() {
  group('a grammar range that follows the words', () {
    test('ends where the words end', () {
      final settings = Settings().withWordRange(LessonRange(1, 23));
      expect(settings.effectiveGrammar, LessonRange(1, 23));
      expect(settings.courseGrammar, LessonRange(1, 23));
    });

    test('is the full grammar range when the words reach the last lesson', () {
      final settings = Settings().withWordRange(LessonRange(1, lastLesson));
      expect(settings.effectiveGrammar, LessonRange.fullGrammar);
      expect(settings.effectiveGrammar, LessonRange(1, laterLesson));
    });

    test('follows again after being unlinked', () {
      final settings = Settings()
          .withWordRange(LessonRange(1, 10))
          .withGrammarFollowsWords(false)
          .withWordRange(LessonRange(1, 30));
      expect(settings.effectiveGrammar, LessonRange(1, 10));
      expect(
        settings.withGrammarFollowsWords(true).effectiveGrammar,
        LessonRange(1, 30),
      );
      expect(
        Settings(courseWords: LessonRange(1, lastLesson))
            .withGrammarFollowsWords(true)
            .effectiveGrammar,
        LessonRange.fullGrammar,
      );
    });

    test('is the full grammar range by default', () {
      expect(Settings().courseWords, LessonRange.fullWords);
      expect(Settings().effectiveGrammar, LessonRange.fullGrammar);
    });
  });
}
