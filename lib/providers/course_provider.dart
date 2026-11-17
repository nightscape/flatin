import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/practice_data.dart';
import '../models/course.dart';

part 'course_provider.g.dart';

/// The checked courses of the course list.
@Riverpod(keepAlive: true)
Future<List<Course>> courses(Ref ref) => loadCourses();

/// The id of the course the learner reads: the stored choice, else the first
/// course.
@Riverpod(keepAlive: true)
class ActiveCourse extends _$ActiveCourse {
  @override
  Future<String> build() async {
    final courses = await ref.watch(coursesProvider.future);
    final id = activeOf(
      courses,
      (await SharedPreferences.getInstance()).getString(activeCourseKey),
    ).id;
    useCourse(id);
    return id;
  }

  Future<void> select(String id) async {
    final courses = await ref.read(coursesProvider.future);
    assert(courses.any((c) => c.id == id), 'no course "$id"');
    await (await SharedPreferences.getInstance()).setString(
      activeCourseKey,
      id,
    );
    useCourse(id);
    resetPracticeData();
    state = AsyncData(id);
  }
}

/// The course the app runs.
@Riverpod(keepAlive: true)
Future<Course> course(Ref ref) async {
  final id = await ref.watch(activeCourseProvider.future);
  return (await ref.watch(
    coursesProvider.future,
  )).singleWhere((c) => c.id == id);
}

/// The active course with its list, for the storage keys of per-course data.
@Riverpod(keepAlive: true)
Future<CourseScope> courseScope(Ref ref) async => CourseScope(
  await ref.watch(coursesProvider.future),
  await ref.watch(courseProvider.future),
);
