// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The checked courses of the course list.

@ProviderFor(courses)
final coursesProvider = CoursesProvider._();

/// The checked courses of the course list.

final class CoursesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Course>>,
          List<Course>,
          FutureOr<List<Course>>
        >
    with $FutureModifier<List<Course>>, $FutureProvider<List<Course>> {
  /// The checked courses of the course list.
  CoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coursesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coursesHash();

  @$internal
  @override
  $FutureProviderElement<List<Course>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Course>> create(Ref ref) {
    return courses(ref);
  }
}

String _$coursesHash() => r'19393b2060fe86e25a2f94837297911cb933b771';

/// The id of the course the learner reads: the stored choice, else the first
/// course.

@ProviderFor(ActiveCourse)
final activeCourseProvider = ActiveCourseProvider._();

/// The id of the course the learner reads: the stored choice, else the first
/// course.
final class ActiveCourseProvider
    extends $AsyncNotifierProvider<ActiveCourse, String> {
  /// The id of the course the learner reads: the stored choice, else the first
  /// course.
  ActiveCourseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCourseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCourseHash();

  @$internal
  @override
  ActiveCourse create() => ActiveCourse();
}

String _$activeCourseHash() => r'855350cc66ecb1a33862a708b78c15fa2fdb0904';

/// The id of the course the learner reads: the stored choice, else the first
/// course.

abstract class _$ActiveCourse extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The course the app runs.

@ProviderFor(course)
final courseProvider = CourseProvider._();

/// The course the app runs.

final class CourseProvider
    extends $FunctionalProvider<AsyncValue<Course>, Course, FutureOr<Course>>
    with $FutureModifier<Course>, $FutureProvider<Course> {
  /// The course the app runs.
  CourseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseHash();

  @$internal
  @override
  $FutureProviderElement<Course> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Course> create(Ref ref) {
    return course(ref);
  }
}

String _$courseHash() => r'de82387d70971b6a240878785e49dc226bafa67f';

/// The active course with its list, for the storage keys of per-course data.

@ProviderFor(courseScope)
final courseScopeProvider = CourseScopeProvider._();

/// The active course with its list, for the storage keys of per-course data.

final class CourseScopeProvider
    extends
        $FunctionalProvider<
          AsyncValue<CourseScope>,
          CourseScope,
          FutureOr<CourseScope>
        >
    with $FutureModifier<CourseScope>, $FutureProvider<CourseScope> {
  /// The active course with its list, for the storage keys of per-course data.
  CourseScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseScopeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseScopeHash();

  @$internal
  @override
  $FutureProviderElement<CourseScope> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CourseScope> create(Ref ref) {
    return courseScope(ref);
  }
}

String _$courseScopeHash() => r'd21ea942e517e191d9a4f40fc618e0b25dbc5848';
