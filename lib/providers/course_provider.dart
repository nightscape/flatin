import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/course.dart';

part 'course_provider.g.dart';

/// The checked courses of the course list.
@Riverpod(keepAlive: true)
Future<List<Course>> courses(Ref ref) => loadCourses();

/// The course the app runs.
@Riverpod(keepAlive: true)
Future<Course> course(Ref ref) async =>
    (await ref.watch(coursesProvider.future)).single;
