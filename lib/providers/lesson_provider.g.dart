// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lesson → word mapping for the currently-configured textbook.

@ProviderFor(lessonData)
const lessonDataProvider = LessonDataProvider._();

/// The lesson → word mapping for the currently-configured textbook.

final class LessonDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<LessonData>,
          LessonData,
          FutureOr<LessonData>
        >
    with $FutureModifier<LessonData>, $FutureProvider<LessonData> {
  /// The lesson → word mapping for the currently-configured textbook.
  const LessonDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lessonDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lessonDataHash();

  @$internal
  @override
  $FutureProviderElement<LessonData> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LessonData> create(Ref ref) {
    return lessonData(ref);
  }
}

String _$lessonDataHash() => r'66dcc347cfd91271a204f3e27fe12c6bcfce83a5';
