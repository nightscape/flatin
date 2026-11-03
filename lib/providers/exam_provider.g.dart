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

String _$examLanguageHash() => r'ec80b558c10d0d27b546513c70d4bfd7cdd889bc';

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

/// The app's words by lemma: the meaning in the UI language and the word
/// card ids, one per data file that lists the lemma.

@ProviderFor(examWords)
final examWordsProvider = ExamWordsProvider._();

/// The app's words by lemma: the meaning in the UI language and the word
/// card ids, one per data file that lists the lemma.

final class ExamWordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ({List<String> cardIds, String meaning})>>,
          Map<String, ({List<String> cardIds, String meaning})>,
          FutureOr<Map<String, ({List<String> cardIds, String meaning})>>
        >
    with
        $FutureModifier<Map<String, ({List<String> cardIds, String meaning})>>,
        $FutureProvider<Map<String, ({List<String> cardIds, String meaning})>> {
  /// The app's words by lemma: the meaning in the UI language and the word
  /// card ids, one per data file that lists the lemma.
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
  $FutureProviderElement<Map<String, ({List<String> cardIds, String meaning})>>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, ({List<String> cardIds, String meaning})>> create(
    Ref ref,
  ) {
    return examWords(ref);
  }
}

String _$examWordsHash() => r'976e608abc2eb2d05fb955418c83586cfd521ad3';
