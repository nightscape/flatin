// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lesson → word mapping of the configured volumes.

@ProviderFor(lessonData)
final lessonDataProvider = LessonDataProvider._();

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
  LessonDataProvider._()
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

/// Every practice item of the loaded data files, nouns first.

@ProviderFor(practiceItems)
final practiceItemsProvider = PracticeItemsProvider._();

/// Every practice item of the loaded data files, nouns first.

final class PracticeItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PracticeItem>>,
          List<PracticeItem>,
          FutureOr<List<PracticeItem>>
        >
    with
        $FutureModifier<List<PracticeItem>>,
        $FutureProvider<List<PracticeItem>> {
  /// Every practice item of the loaded data files, nouns first.
  PracticeItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'practiceItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$practiceItemsHash();

  @$internal
  @override
  $FutureProviderElement<List<PracticeItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PracticeItem>> create(Ref ref) {
    return practiceItems(ref);
  }
}

String _$practiceItemsHash() => r'c7a68183fa6e0e742032adc3adf5796fe0a51649';
