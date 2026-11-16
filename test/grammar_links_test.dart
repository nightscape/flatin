import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'support/latin_course.dart'
    show latinFullRange, latinLastLesson, latinLaterLesson;

Settings _load(Map<String, dynamic> stored) => Settings.fromJson(
  jsonDecode(jsonEncode({settingsVersionField: settingsVersion, ...stored}))
      as Map<String, dynamic>,
  lastLesson: latinLastLesson,
);

void main() {
  group('the grammar links', () {
    test('by default only the upper bounds are linked', () {
      final settings = Settings(lastLesson: latinLastLesson);
      expect(settings.grammarFromLinked, isFalse);
      expect(settings.grammarToLinked, isTrue);
      expect(settings.courseWords, latinFullRange);
      expect(settings.courseGrammar, latinFullRange);
    });

    test('a linked upper bound ends where the words end, Später too', () {
      expect(
        Settings(
          lastLesson: latinLastLesson,
        ).withWordRange(LessonRange(5, 23)).courseGrammar,
        LessonRange(1, 23),
      );
      expect(
        Settings(
          lastLesson: latinLastLesson,
        ).withWordRange(LessonRange(5, latinLaterLesson)).courseGrammar,
        LessonRange(1, latinLaterLesson),
      );
    });

    test('a linked lower bound starts where the words start', () {
      final settings = Settings(
        lastLesson: latinLastLesson,
      ).withGrammarLinked(from: true).withWordRange(LessonRange(7, 12));
      expect(settings.courseGrammar, LessonRange(7, 12));
    });

    test('an open bound stays, pushed only to keep the range non-empty', () {
      final settings = Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(20, 30),
        courseGrammar: LessonRange(25, 35),
        grammarToLinked: false,
      ).withGrammarLinked(from: true);
      expect(settings.courseGrammar, LessonRange(20, 35));
      expect(
        settings
            .withGrammarLinked(from: false, to: true)
            .withWordRange(LessonRange(2, 3))
            .courseGrammar,
        LessonRange(3, 3),
      );
    });

    test('linking a bound snaps it to the word bound', () {
      final settings = Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(5, 12),
        courseGrammar: LessonRange(1, 3),
        grammarToLinked: false,
      );
      expect(
        settings.withGrammarLinked(to: true).courseGrammar,
        LessonRange(1, 12),
      );
      expect(
        settings.withGrammarLinked(from: true).courseGrammar,
        LessonRange(5, 5),
      );
    });

    test('moving a linked grammar bound unlinks only that bound', () {
      final both = Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(5, 12),
        grammarFromLinked: true,
      );
      final upper = both.withGrammarRange(LessonRange(5, 20));
      expect(upper.grammarFromLinked, isTrue);
      expect(upper.grammarToLinked, isFalse);
      expect(upper.courseGrammar, LessonRange(5, 20));

      final lower = both.withGrammarRange(LessonRange(2, 12));
      expect(lower.grammarFromLinked, isFalse);
      expect(lower.grammarToLinked, isTrue);
    });

    test('both links survive a JSON round trip', () {
      final settings = Settings(
        lastLesson: latinLastLesson,
        courseWords: LessonRange(4, 17),
        courseGrammar: LessonRange(1, 9),
        grammarFromLinked: true,
        grammarToLinked: false,
      );
      final restored = _load(settings.toJson());
      expect(restored.grammarFromLinked, isTrue);
      expect(restored.grammarToLinked, isFalse);
      expect(restored.courseGrammar, LessonRange(4, 9));
      expect(restored.toJson().containsKey('grammarFollowsWords'), isFalse);
    });
  });

  group('settings stored with the single link', () {
    test('true loads as the upper bounds linked, the lower ones open', () {
      final settings = _load({
        'courseWords': {'from': 21, 'to': 23},
        'courseGrammar': {'from': 1, 'to': 23},
        'grammarFollowsWords': true,
      });
      expect(settings.grammarFromLinked, isFalse);
      expect(settings.grammarToLinked, isTrue);
      expect(settings.courseWords, LessonRange(21, 23));
      expect(settings.courseGrammar, LessonRange(1, 23));
    });

    test('true with the words at the last lesson keeps the grammar on '
        'Später', () {
      final settings = _load({
        'courseWords': {'from': 3, 'to': latinLastLesson},
        'courseGrammar': {'from': 1, 'to': latinLaterLesson},
        'grammarFollowsWords': true,
      });
      expect(settings.courseWords, LessonRange(3, latinLaterLesson));
      expect(settings.courseGrammar, LessonRange(1, latinLaterLesson));
    });

    test('false loads as both bounds open', () {
      final settings = _load({
        'courseWords': {'from': 4, 'to': latinLastLesson},
        'courseGrammar': {'from': 2, 'to': 9},
        'grammarFollowsWords': false,
      });
      expect(settings.grammarFromLinked, isFalse);
      expect(settings.grammarToLinked, isFalse);
      expect(settings.courseWords, LessonRange(4, latinLastLesson));
      expect(settings.courseGrammar, LessonRange(2, 9));
    });

    test('settings stored before any link load as the default', () {
      final settings = _load({});
      expect(settings.grammarFromLinked, isFalse);
      expect(settings.grammarToLinked, isTrue);
      expect(settings.courseWords, latinFullRange);
      expect(settings.courseGrammar, latinFullRange);
    });
  });
}
