// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The grammar progression of the configured volumes.

@ProviderFor(curriculum)
const curriculumProvider = CurriculumProvider._();

/// The grammar progression of the configured volumes.

final class CurriculumProvider
    extends
        $FunctionalProvider<
          AsyncValue<Curriculum>,
          Curriculum,
          FutureOr<Curriculum>
        >
    with $FutureModifier<Curriculum>, $FutureProvider<Curriculum> {
  /// The grammar progression of the configured volumes.
  const CurriculumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curriculumProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curriculumHash();

  @$internal
  @override
  $FutureProviderElement<Curriculum> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Curriculum> create(Ref ref) {
    return curriculum(ref);
  }
}

String _$curriculumHash() => r'e53e1462113b6de463af72880b91c82fb983f7c3';

/// What the learner practises at the current course position.

@ProviderFor(courseFilter)
const courseFilterProvider = CourseFilterProvider._();

/// What the learner practises at the current course position.

final class CourseFilterProvider
    extends
        $FunctionalProvider<
          AsyncValue<CourseFilter>,
          CourseFilter,
          FutureOr<CourseFilter>
        >
    with $FutureModifier<CourseFilter>, $FutureProvider<CourseFilter> {
  /// What the learner practises at the current course position.
  const CourseFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseFilterHash();

  @$internal
  @override
  $FutureProviderElement<CourseFilter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CourseFilter> create(Ref ref) {
    return courseFilter(ref);
  }
}

String _$courseFilterHash() => r'55b59d7a19a2d0f832995c0b0a18cb1a42c111c9';
