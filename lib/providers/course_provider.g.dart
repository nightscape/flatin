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

String _$courseHash() => r'301b40abba25f2def0bf08a7ac2770da35ab279f';
