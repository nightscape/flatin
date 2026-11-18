import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/curriculum.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';
import '../models/course_filter.dart';
import 'course_provider.dart';
import 'lesson_provider.dart';
import 'settings_provider.dart';

part 'curriculum_provider.g.dart';

/// The grammar progression of the configured volumes.
@riverpod
Future<Curriculum> curriculum(Ref ref) async {
  final course = await ref.watch(courseProvider.future);
  assert(
    course.books.isNotEmpty,
    '${course.path} has no books, so no curriculum',
  );
  return loadCurriculum(course.books);
}

/// What the learner practises at the current course position.
@riverpod
Future<CourseFilter> courseFilter(Ref ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final lessons = await ref.watch(lessonDataProvider.future);
  assertLessonsCoverItems(lessons, await loadAllPracticeItems());
  return CourseFilter(
    settings,
    await ref.watch(curriculumProvider.future),
    lessons,
  );
}
