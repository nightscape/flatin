// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fsrs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// FSRS Scheduler instance provider

@ProviderFor(fsrsScheduler)
final fsrsSchedulerProvider = FsrsSchedulerProvider._();

/// FSRS Scheduler instance provider

final class FsrsSchedulerProvider
    extends $FunctionalProvider<Scheduler, Scheduler, Scheduler>
    with $Provider<Scheduler> {
  /// FSRS Scheduler instance provider
  FsrsSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fsrsSchedulerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fsrsSchedulerHash();

  @$internal
  @override
  $ProviderElement<Scheduler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Scheduler create(Ref ref) {
    return fsrsScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Scheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Scheduler>(value),
    );
  }
}

String _$fsrsSchedulerHash() => r'0d0b3a951dcad9e3faed4e21fd6e20e0439cc4c5';

/// Every word card and grammar card of the active course, synced with the
/// YAML items. The cards of the other courses stay in the store untouched.

@ProviderFor(fsrsCards)
final fsrsCardsProvider = FsrsCardsProvider._();

/// Every word card and grammar card of the active course, synced with the
/// YAML items. The cards of the other courses stay in the store untouched.

final class FsrsCardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, PracticeItemCard>>,
          Map<String, PracticeItemCard>,
          FutureOr<Map<String, PracticeItemCard>>
        >
    with
        $FutureModifier<Map<String, PracticeItemCard>>,
        $FutureProvider<Map<String, PracticeItemCard>> {
  /// Every word card and grammar card of the active course, synced with the
  /// YAML items. The cards of the other courses stay in the store untouched.
  FsrsCardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fsrsCardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fsrsCardsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, PracticeItemCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, PracticeItemCard>> create(Ref ref) {
    return fsrsCards(ref);
  }
}

String _$fsrsCardsHash() => r'8cb038f0f95941da0d1c7183b883fcd3d405b20c';

/// The due word cards; grammar and stem cards are due through the rounds.

@ProviderFor(dueCards)
final dueCardsProvider = DueCardsProvider._();

/// The due word cards; grammar and stem cards are due through the rounds.

final class DueCardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PracticeItemCard>>,
          List<PracticeItemCard>,
          FutureOr<List<PracticeItemCard>>
        >
    with
        $FutureModifier<List<PracticeItemCard>>,
        $FutureProvider<List<PracticeItemCard>> {
  /// The due word cards; grammar and stem cards are due through the rounds.
  DueCardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueCardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueCardsHash();

  @$internal
  @override
  $FutureProviderElement<List<PracticeItemCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PracticeItemCard>> create(Ref ref) {
    return dueCards(ref);
  }
}

String _$dueCardsHash() => r'86d845a7f20c12a6df3067d38802a998d5a04291';

/// Every item the user can practise, by exercise type.
///
/// The one place the course filter is applied, so that no consumer can route
/// around it. An item whose forms are all untaught or switched off has
/// nothing to ask and is left out.

@ProviderFor(practicableItemsByFile)
final practicableItemsByFileProvider = PracticableItemsByFileProvider._();

/// Every item the user can practise, by exercise type.
///
/// The one place the course filter is applied, so that no consumer can route
/// around it. An item whose forms are all untaught or switched off has
/// nothing to ask and is left out.

final class PracticableItemsByFileProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<PracticeItem>>>,
          Map<String, List<PracticeItem>>,
          FutureOr<Map<String, List<PracticeItem>>>
        >
    with
        $FutureModifier<Map<String, List<PracticeItem>>>,
        $FutureProvider<Map<String, List<PracticeItem>>> {
  /// Every item the user can practise, by exercise type.
  ///
  /// The one place the course filter is applied, so that no consumer can route
  /// around it. An item whose forms are all untaught or switched off has
  /// nothing to ask and is left out.
  PracticableItemsByFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'practicableItemsByFileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$practicableItemsByFileHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<PracticeItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<PracticeItem>>> create(Ref ref) {
    return practicableItemsByFile(ref);
  }
}

String _$practicableItemsByFileHash() =>
    r'4d7de4e11527252f9e86df4d9a11c56dc3e3d264';

/// Provider for due items by exercise type

@ProviderFor(dueItemsByFile)
final dueItemsByFileProvider = DueItemsByFileProvider._();

/// Provider for due items by exercise type

final class DueItemsByFileProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<PracticeItem>>>,
          Map<String, List<PracticeItem>>,
          FutureOr<Map<String, List<PracticeItem>>>
        >
    with
        $FutureModifier<Map<String, List<PracticeItem>>>,
        $FutureProvider<Map<String, List<PracticeItem>>> {
  /// Provider for due items by exercise type
  DueItemsByFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueItemsByFileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueItemsByFileHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<PracticeItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<PracticeItem>>> create(Ref ref) {
    return dueItemsByFile(ref);
  }
}

String _$dueItemsByFileHash() => r'b67bbeb2e89648679f73450d1954fad529d8fb86';

/// The next due item of [dataFileId] that [focus] includes.

@ProviderFor(nextDueItem)
final nextDueItemProvider = NextDueItemFamily._();

/// The next due item of [dataFileId] that [focus] includes.

final class NextDueItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<PracticeItem?>,
          PracticeItem?,
          FutureOr<PracticeItem?>
        >
    with $FutureModifier<PracticeItem?>, $FutureProvider<PracticeItem?> {
  /// The next due item of [dataFileId] that [focus] includes.
  NextDueItemProvider._({
    required NextDueItemFamily super.from,
    required (String, WordFocus) super.argument,
  }) : super(
         retry: null,
         name: r'nextDueItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nextDueItemHash();

  @override
  String toString() {
    return r'nextDueItemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PracticeItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PracticeItem?> create(Ref ref) {
    final argument = this.argument as (String, WordFocus);
    return nextDueItem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is NextDueItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nextDueItemHash() => r'63b5b27c0852fffa5b7be9c5d8bb9f0f1ed038a3';

/// The next due item of [dataFileId] that [focus] includes.

final class NextDueItemFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PracticeItem?>,
          (String, WordFocus)
        > {
  NextDueItemFamily._()
    : super(
        retry: null,
        name: r'nextDueItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The next due item of [dataFileId] that [focus] includes.

  NextDueItemProvider call(String dataFileId, WordFocus focus) =>
      NextDueItemProvider._(argument: (dataFileId, focus), from: this);

  @override
  String toString() => r'nextDueItemProvider';
}

/// The focus choices for the words in the course range.

@ProviderFor(wordFocuses)
final wordFocusesProvider = WordFocusesProvider._();

/// The focus choices for the words in the course range.

final class WordFocusesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WordFocus>>,
          List<WordFocus>,
          FutureOr<List<WordFocus>>
        >
    with $FutureModifier<List<WordFocus>>, $FutureProvider<List<WordFocus>> {
  /// The focus choices for the words in the course range.
  WordFocusesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordFocusesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordFocusesHash();

  @$internal
  @override
  $FutureProviderElement<List<WordFocus>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WordFocus>> create(Ref ref) {
    return wordFocuses(ref);
  }
}

String _$wordFocusesHash() => r'3927a98619d6dd398d00d7113c7b68c9ca48a4db';

/// How the prompts mark stems. Before the settings load, the default.

@ProviderFor(stemMarking)
final stemMarkingProvider = StemMarkingProvider._();

/// How the prompts mark stems. Before the settings load, the default.

final class StemMarkingProvider
    extends $FunctionalProvider<StemMarking, StemMarking, StemMarking>
    with $Provider<StemMarking> {
  /// How the prompts mark stems. Before the settings load, the default.
  StemMarkingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stemMarkingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stemMarkingHash();

  @$internal
  @override
  $ProviderElement<StemMarking> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StemMarking create(Ref ref) {
    return stemMarking(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StemMarking value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StemMarking>(value),
    );
  }
}

String _$stemMarkingHash() => r'c454cb9d1ed55a5003a6143a3e372ee86936ec18';

/// The German texts of the Latin verbs and nouns; none for a UI language
/// other than German, so the kinds that show them are not built.

@ProviderFor(germanForms)
final germanFormsProvider = GermanFormsProvider._();

/// The German texts of the Latin verbs and nouns; none for a UI language
/// other than German, so the kinds that show them are not built.

final class GermanFormsProvider
    extends
        $FunctionalProvider<
          AsyncValue<GermanForms>,
          GermanForms,
          FutureOr<GermanForms>
        >
    with $FutureModifier<GermanForms>, $FutureProvider<GermanForms> {
  /// The German texts of the Latin verbs and nouns; none for a UI language
  /// other than German, so the kinds that show them are not built.
  GermanFormsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'germanFormsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$germanFormsHash();

  @$internal
  @override
  $FutureProviderElement<GermanForms> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GermanForms> create(Ref ref) {
    return germanForms(ref);
  }
}

String _$germanFormsHash() => r'429b45b6e9605042a77f71af93e06dc679524d88';

/// The randomness of the grammar exercises; a test overrides it with a seed.

@ProviderFor(exerciseRandom)
final exerciseRandomProvider = ExerciseRandomProvider._();

/// The randomness of the grammar exercises; a test overrides it with a seed.

final class ExerciseRandomProvider
    extends $FunctionalProvider<Random, Random, Random>
    with $Provider<Random> {
  /// The randomness of the grammar exercises; a test overrides it with a seed.
  ExerciseRandomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseRandomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseRandomHash();

  @$internal
  @override
  $ProviderElement<Random> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Random create(Ref ref) {
    return exerciseRandom(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Random value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Random>(value),
    );
  }
}

String _$exerciseRandomHash() => r'258d487e43bad86c36fc9c10bd41f968162897ee';

/// The generators that build the grammar exercises; a test overrides it.

@ProviderFor(exerciseRegistry)
final exerciseRegistryProvider = ExerciseRegistryProvider._();

/// The generators that build the grammar exercises; a test overrides it.

final class ExerciseRegistryProvider
    extends
        $FunctionalProvider<
          List<ExerciseGenerator>,
          List<ExerciseGenerator>,
          List<ExerciseGenerator>
        >
    with $Provider<List<ExerciseGenerator>> {
  /// The generators that build the grammar exercises; a test overrides it.
  ExerciseRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseRegistryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseRegistryHash();

  @$internal
  @override
  $ProviderElement<List<ExerciseGenerator>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ExerciseGenerator> create(Ref ref) {
    return exerciseRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ExerciseGenerator> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ExerciseGenerator>>(value),
    );
  }
}

String _$exerciseRegistryHash() => r'e479eb1b79bd335ee4b0296bcde4cbb5a9f82a7f';

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.

@ProviderFor(translationChoices)
final translationChoicesProvider = TranslationChoicesFamily._();

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.

final class TranslationChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Provides shuffled translation choices for a practice item:
  /// the correct translation plus 3 distractors from the chosen strategy.
  TranslationChoicesProvider._({
    required TranslationChoicesFamily super.from,
    required PracticeItem super.argument,
  }) : super(
         retry: null,
         name: r'translationChoicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$translationChoicesHash();

  @override
  String toString() {
    return r'translationChoicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as PracticeItem;
    return translationChoices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TranslationChoicesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$translationChoicesHash() =>
    r'7aaf974971edf3e22b06561e6f015c4c0a67ecf6';

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.

final class TranslationChoicesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, PracticeItem> {
  TranslationChoicesFamily._()
    : super(
        retry: null,
        name: r'translationChoicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides shuffled translation choices for a practice item:
  /// the correct translation plus 3 distractors from the chosen strategy.

  TranslationChoicesProvider call(PracticeItem item) =>
      TranslationChoicesProvider._(argument: item, from: this);

  @override
  String toString() => r'translationChoicesProvider';
}
