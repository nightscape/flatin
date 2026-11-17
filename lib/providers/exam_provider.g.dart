// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The language of the active course: its codes, spelling folds and rules.

@ProviderFor(courseLanguage)
final courseLanguageProvider = CourseLanguageProvider._();

/// The language of the active course: its codes, spelling folds and rules.

final class CourseLanguageProvider
    extends
        $FunctionalProvider<AsyncValue<Language>, Language, FutureOr<Language>>
    with $FutureModifier<Language>, $FutureProvider<Language> {
  /// The language of the active course: its codes, spelling folds and rules.
  CourseLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseLanguageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseLanguageHash();

  @$internal
  @override
  $FutureProviderElement<Language> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Language> create(Ref ref) {
    return courseLanguage(ref);
  }
}

String _$courseLanguageHash() => r'853c6432220b1c568dfc91e56b31030646588e60';

/// The language whose codes and rules the exam packs of the active course use.

@ProviderFor(examLanguage)
final examLanguageProvider = ExamLanguageProvider._();

/// The language whose codes and rules the exam packs of the active course use.

final class ExamLanguageProvider
    extends
        $FunctionalProvider<AsyncValue<Language>, Language, FutureOr<Language>>
    with $FutureModifier<Language>, $FutureProvider<Language> {
  /// The language whose codes and rules the exam packs of the active course use.
  ExamLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'examLanguageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$examLanguageHash();

  @$internal
  @override
  $FutureProviderElement<Language> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Language> create(Ref ref) {
    return examLanguage(ref);
  }
}

String _$examLanguageHash() => r'2c0adba1752929d29dde6a58d7dbb16961842398';

/// The imported exam packs of the active course.

@ProviderFor(ExamPacks)
final examPacksProvider = ExamPacksProvider._();

/// The imported exam packs of the active course.
final class ExamPacksProvider
    extends $AsyncNotifierProvider<ExamPacks, List<Exam>> {
  /// The imported exam packs of the active course.
  ExamPacksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'examPacksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$examPacksHash();

  @$internal
  @override
  ExamPacks create() => ExamPacks();
}

String _$examPacksHash() => r'612e53b3e0b452ee6e09aee3682d76c45e1d7708';

/// The imported exam packs of the active course.

abstract class _$ExamPacks extends $AsyncNotifier<List<Exam>> {
  FutureOr<List<Exam>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Exam>>, List<Exam>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Exam>>, List<Exam>>,
              AsyncValue<List<Exam>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// By data file id, each grammar file's axes that the language forms words
/// with (`form`), in the language of the UI and in the order of that file,
/// with the codes of the language's `analyse` only: the analysis keys that
/// have a dropdown. A file with no such axis is left out.

@ProviderFor(examAxes)
final examAxesProvider = ExamAxesProvider._();

/// By data file id, each grammar file's axes that the language forms words
/// with (`form`), in the language of the UI and in the order of that file,
/// with the codes of the language's `analyse` only: the analysis keys that
/// have a dropdown. A file with no such axis is left out.

final class ExamAxesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Axes>>,
          Map<String, Axes>,
          FutureOr<Map<String, Axes>>
        >
    with
        $FutureModifier<Map<String, Axes>>,
        $FutureProvider<Map<String, Axes>> {
  /// By data file id, each grammar file's axes that the language forms words
  /// with (`form`), in the language of the UI and in the order of that file,
  /// with the codes of the language's `analyse` only: the analysis keys that
  /// have a dropdown. A file with no such axis is left out.
  ExamAxesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'examAxesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$examAxesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Axes>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Axes>> create(Ref ref) {
    return examAxes(ref);
  }
}

String _$examAxesHash() => r'98fe63bc8f734c121468fa6e74c03dcc810b829c';

/// The app's words by lemma: the meaning in the UI language, and the word
/// card id and data file, one per data file that lists the lemma.

@ProviderFor(examWords)
final examWordsProvider = ExamWordsProvider._();

/// The app's words by lemma: the meaning in the UI language, and the word
/// card id and data file, one per data file that lists the lemma.

final class ExamWordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ExamWord>>,
          Map<String, ExamWord>,
          FutureOr<Map<String, ExamWord>>
        >
    with
        $FutureModifier<Map<String, ExamWord>>,
        $FutureProvider<Map<String, ExamWord>> {
  /// The app's words by lemma: the meaning in the UI language, and the word
  /// card id and data file, one per data file that lists the lemma.
  ExamWordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'examWordsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$examWordsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, ExamWord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, ExamWord>> create(Ref ref) {
    return examWords(ref);
  }
}

String _$examWordsHash() => r'a9cf6e6fa1dc32ed0e3b17cb12c6c22d73b7580b';

/// Where the course teaches its words.

@ProviderFor(lessonLookup)
final lessonLookupProvider = LessonLookupProvider._();

/// Where the course teaches its words.

final class LessonLookupProvider
    extends
        $FunctionalProvider<
          AsyncValue<LessonLookup>,
          LessonLookup,
          FutureOr<LessonLookup>
        >
    with $FutureModifier<LessonLookup>, $FutureProvider<LessonLookup> {
  /// Where the course teaches its words.
  LessonLookupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lessonLookupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lessonLookupHash();

  @$internal
  @override
  $FutureProviderElement<LessonLookup> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LessonLookup> create(Ref ref) {
    return lessonLookup(ref);
  }
}

String _$lessonLookupHash() => r'2ddd9d40e14e7bda611c95d7e075bdbc5afd0f4b';
