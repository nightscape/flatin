import 'dart:io';

import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:yaml/yaml.dart';

/// The one course of [coursesAsset], read from the repo without the asset
/// bundle.
final Course latinCourse = () {
  final path =
      (loadYaml(File(coursesAsset).readAsStringSync()) as YamlList).first
          as String;
  return Course.parse(path, File(path).readAsStringSync());
}();

/// The language file of [latinCourse].
final Language latinLang = Language.parse(
  File(latinCourse.language).readAsStringSync(),
);

/// The length of [latinCourse]: its highest lesson.
final int latinLastLesson = lastLessonOf(latinCourse);

/// The highest lesson of [course]'s books.
int lastLessonOf(Course course) => [
  for (final path in course.books)
    for (final lesson
        in (loadYaml(File(path).readAsStringSync()) as YamlMap)['lessons']
            as YamlList)
      (lesson as YamlMap)['lesson'] as int,
].reduce((a, b) => a > b ? a : b);

/// The "Später" stop of [latinCourse].
final int latinLaterLesson = latinLastLesson + 1;

/// All lessons of [latinCourse], "Später" included.
final LessonRange latinFullRange = LessonRange(1, latinLaterLesson);
