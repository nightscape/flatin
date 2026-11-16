import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_language.dart';
import 'tracer/toy_assets.dart';

const _seeds = 25;

Map<String, String> _served(List<String> books) {
  final manifest =
      jsonDecode(
            jsonEncode(
              loadYaml(File('$toyDir/course.yaml').readAsStringSync()),
            ),
          )
          as Map<String, dynamic>;
  final paths = [for (var i = 0; i < books.length; i++) 'drawn/book_$i.yaml'];
  manifest['books'] = paths;
  return {
    coursesAsset: '- drawn/course.yaml',
    'drawn/course.yaml': jsonEncode(manifest),
    for (final (i, path) in paths.indexed) path: books[i],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the course length is the highest lesson of the drawn books', () async {
    for (var seed = 0; seed < _seeds; seed++) {
      final drawn = drawnCourseBooks(Random(seed));
      injectToyCourse(served: _served(drawn.books));
      final lessons = await loadLessonData((await loadCourse()).books);

      final reason = 'seed $seed, ${drawn.lessons} lessons';
      final settings = Settings(lastLesson: lessons.lastLesson);
      expect(lessons.lastLesson, drawn.lessons, reason: reason);
      expect(lessons.laterLesson, drawn.lessons + 1, reason: reason);
      expect(settings.fullRange.to, drawn.lessons + 1, reason: reason);
      expect(settings.kursstand, drawn.lessons, reason: reason);
      expect(settings.courseWords, settings.fullRange, reason: reason);
    }
  });

  test('settings beyond the drawn course length are refused', () {
    for (var seed = 0; seed < _seeds; seed++) {
      final n = 1 + Random(seed).nextInt(60);
      expect(
        () => Settings(lastLesson: n, kursstand: n + 1),
        throwsA(isA<AssertionError>()),
        reason: 'seed $seed, length $n: Kursstand past the last lesson',
      );
      expect(
        () => Settings(lastLesson: n, courseWords: LessonRange(1, n + 2)),
        throwsA(isA<AssertionError>()),
        reason: 'seed $seed, length $n: range past "Später"',
      );
      expect(
        () => Settings(
          lastLesson: n,
          courseGrammar: LessonRange(1, n + 2),
          grammarToLinked: false,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'seed $seed, length $n: grammar range past "Später"',
      );
    }
  });

  test('a lesson missing below the highest one is named', () async {
    for (var seed = 0; seed < _seeds; seed++) {
      final drawn = drawnCourseBooks(Random(seed), withGap: true);
      injectToyCourse(served: _served(drawn.books));
      await expectLater(
        loadLessonData((await loadCourse()).books),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no lesson ${drawn.gap}'),
          ),
        ),
        reason: 'seed $seed',
      );
    }
  });
}
