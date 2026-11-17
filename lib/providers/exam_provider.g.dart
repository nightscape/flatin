// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The language whose codes and rules the exam packs use.

@ProviderFor(examLanguage)
final examLanguageProvider = ExamLanguageProvider._();

/// The language whose codes and rules the exam packs use.

final class ExamLanguageProvider
    extends
        $FunctionalProvider<AsyncValue<Language>, Language, FutureOr<Language>>
    with $FutureModifier<Language>, $FutureProvider<Language> {
  /// The language whose codes and rules the exam packs use.
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

String _$examLanguageHash() => r'2db64d5c7033e10cef8fe10a04d1aea1aef049bb';

/// The imported exam packs.

@ProviderFor(ExamPacks)
final examPacksProvider = ExamPacksProvider._();

/// The imported exam packs.
final class ExamPacksProvider
    extends $AsyncNotifierProvider<ExamPacks, List<Exam>> {
  /// The imported exam packs.
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

String _$examPacksHash() => r'5a0866c6aba750aaa1c42cf988b132bf3d1b1ac9';

/// The imported exam packs.

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

/// The axes of the course's grammar files that the language forms words
/// with (`form`), in the language of the UI; an axis id that several files
/// declare is taken from the first. These are the analysis keys that have a
/// dropdown, with the codes of the language's `analyse` only.

@ProviderFor(examAxes)
final examAxesProvider = ExamAxesProvider._();

/// The axes of the course's grammar files that the language forms words
/// with (`form`), in the language of the UI; an axis id that several files
/// declare is taken from the first. These are the analysis keys that have a
/// dropdown, with the codes of the language's `analyse` only.

final class ExamAxesProvider
    extends $FunctionalProvider<AsyncValue<Axes>, Axes, FutureOr<Axes>>
    with $FutureModifier<Axes>, $FutureProvider<Axes> {
  /// The axes of the course's grammar files that the language forms words
  /// with (`form`), in the language of the UI; an axis id that several files
  /// declare is taken from the first. These are the analysis keys that have a
  /// dropdown, with the codes of the language's `analyse` only.
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
  $FutureProviderElement<Axes> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Axes> create(Ref ref) {
    return examAxes(ref);
  }
}

String _$examAxesHash() => r'3ed6df0206fed7c614b0b5ab0b3f42c26c355759';

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

/// Where the course teaches the words of the exam sheet.

@ProviderFor(lessonLookup)
final lessonLookupProvider = LessonLookupProvider._();

/// Where the course teaches the words of the exam sheet.

final class LessonLookupProvider
    extends
        $FunctionalProvider<
          AsyncValue<LessonLookup>,
          LessonLookup,
          FutureOr<LessonLookup>
        >
    with $FutureModifier<LessonLookup>, $FutureProvider<LessonLookup> {
  /// Where the course teaches the words of the exam sheet.
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

String _$lessonLookupHash() => r'0c2d74f03dfc150202b1c6b7740b708ca037c180';
