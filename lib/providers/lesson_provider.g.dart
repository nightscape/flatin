// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lesson → word mapping of the configured volumes.

@ProviderFor(lessonData)
const lessonDataProvider = LessonDataProvider._();

/// The lesson → word mapping of the configured volumes.

final class LessonDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<LessonData>,
          LessonData,
          FutureOr<LessonData>
        >
    with $FutureModifier<LessonData>, $FutureProvider<LessonData> {
  /// The lesson → word mapping of the configured volumes.
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

String _$lessonDataHash() => r'a80bdf846f73c3cbd7507c890b86edcf9273b7be';

/// Practisable words that no lesson lists, in YAML order and raw spelling.
///
/// Without them the settings screen has no checkbox for a word the app
/// practises, so it could never be switched off.

@ProviderFor(wordsOutsideLessons)
const wordsOutsideLessonsProvider = WordsOutsideLessonsProvider._();

/// Practisable words that no lesson lists, in YAML order and raw spelling.
///
/// Without them the settings screen has no checkbox for a word the app
/// practises, so it could never be switched off.

final class WordsOutsideLessonsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Practisable words that no lesson lists, in YAML order and raw spelling.
  ///
  /// Without them the settings screen has no checkbox for a word the app
  /// practises, so it could never be switched off.
  const WordsOutsideLessonsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordsOutsideLessonsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordsOutsideLessonsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return wordsOutsideLessons(ref);
  }
}

String _$wordsOutsideLessonsHash() =>
    r'f3b7bd0808b361a62aa916976ab9f4ecafb2d70b';
