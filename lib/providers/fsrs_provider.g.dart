// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fsrs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// FSRS Scheduler instance provider

@ProviderFor(fsrsScheduler)
const fsrsSchedulerProvider = FsrsSchedulerProvider._();

/// FSRS Scheduler instance provider

final class FsrsSchedulerProvider
    extends $FunctionalProvider<Scheduler, Scheduler, Scheduler>
    with $Provider<Scheduler> {
  /// FSRS Scheduler instance provider
  const FsrsSchedulerProvider._()
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

/// Every word card and grammar card, synced with the YAML items.

@ProviderFor(fsrsCards)
const fsrsCardsProvider = FsrsCardsProvider._();

/// Every word card and grammar card, synced with the YAML items.

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
  /// Every word card and grammar card, synced with the YAML items.
  const FsrsCardsProvider._()
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

String _$fsrsCardsHash() => r'c81f641b2179ac611a69a84f1373126f474d0bd7';

/// The due word cards; grammar cards are due through [nextGrammarExercise].

@ProviderFor(dueCards)
const dueCardsProvider = DueCardsProvider._();

/// The due word cards; grammar cards are due through [nextGrammarExercise].

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
  /// The due word cards; grammar cards are due through [nextGrammarExercise].
  const DueCardsProvider._()
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

String _$dueCardsHash() => r'bcb4f761c4f67e8b6321013e4226a3c93ac73f1c';

/// Every item the user can practise, by exercise type.
///
/// The one place the course filter is applied, so that no consumer can route
/// around it. An item whose forms are all untaught or switched off has
/// nothing to ask and is left out.

@ProviderFor(practicableItemsByType)
const practicableItemsByTypeProvider = PracticableItemsByTypeProvider._();

/// Every item the user can practise, by exercise type.
///
/// The one place the course filter is applied, so that no consumer can route
/// around it. An item whose forms are all untaught or switched off has
/// nothing to ask and is left out.

final class PracticableItemsByTypeProvider
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
  const PracticableItemsByTypeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'practicableItemsByTypeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$practicableItemsByTypeHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<PracticeItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<PracticeItem>>> create(Ref ref) {
    return practicableItemsByType(ref);
  }
}

String _$practicableItemsByTypeHash() =>
    r'f23e82cdc0665f095bfe801c1dbc33d9fd1bc290';

/// Provider for due items by exercise type

@ProviderFor(dueItemsByType)
const dueItemsByTypeProvider = DueItemsByTypeProvider._();

/// Provider for due items by exercise type

final class DueItemsByTypeProvider
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
  const DueItemsByTypeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueItemsByTypeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueItemsByTypeHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<PracticeItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<PracticeItem>>> create(Ref ref) {
    return dueItemsByType(ref);
  }
}

String _$dueItemsByTypeHash() => r'949517a59cf37a3b731235668277fa34a6333df3';

/// Get next due item for a specific exercise type

@ProviderFor(nextDueItem)
const nextDueItemProvider = NextDueItemFamily._();

/// Get next due item for a specific exercise type

final class NextDueItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<PracticeItem?>,
          PracticeItem?,
          FutureOr<PracticeItem?>
        >
    with $FutureModifier<PracticeItem?>, $FutureProvider<PracticeItem?> {
  /// Get next due item for a specific exercise type
  const NextDueItemProvider._({
    required NextDueItemFamily super.from,
    required String super.argument,
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
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PracticeItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PracticeItem?> create(Ref ref) {
    final argument = this.argument as String;
    return nextDueItem(ref, argument);
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

String _$nextDueItemHash() => r'dad7b8776eee2406d6d0c580044ff80c0b40d24c';

/// Get next due item for a specific exercise type

final class NextDueItemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PracticeItem?>, String> {
  const NextDueItemFamily._()
    : super(
        retry: null,
        name: r'nextDueItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Get next due item for a specific exercise type

  NextDueItemProvider call(String dataFileId) =>
      NextDueItemProvider._(argument: dataFileId, from: this);

  @override
  String toString() => r'nextDueItemProvider';
}

/// The German texts of the Latin verbs; none for a UI language other than
/// German, so the kinds that show them are not built.

@ProviderFor(germanForms)
const germanFormsProvider = GermanFormsProvider._();

/// The German texts of the Latin verbs; none for a UI language other than
/// German, so the kinds that show them are not built.

final class GermanFormsProvider
    extends
        $FunctionalProvider<
          AsyncValue<GermanForms>,
          GermanForms,
          FutureOr<GermanForms>
        >
    with $FutureModifier<GermanForms>, $FutureProvider<GermanForms> {
  /// The German texts of the Latin verbs; none for a UI language other than
  /// German, so the kinds that show them are not built.
  const GermanFormsProvider._()
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

String _$germanFormsHash() => r'0b654b99c941e8db5c1d5156bcd7a1632593ab82';

/// The randomness of the grammar exercises; a test overrides it with a seed.

@ProviderFor(exerciseRandom)
const exerciseRandomProvider = ExerciseRandomProvider._();

/// The randomness of the grammar exercises; a test overrides it with a seed.

final class ExerciseRandomProvider
    extends $FunctionalProvider<Random, Random, Random>
    with $Provider<Random> {
  /// The randomness of the grammar exercises; a test overrides it with a seed.
  const ExerciseRandomProvider._()
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
const exerciseRegistryProvider = ExerciseRegistryProvider._();

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
  const ExerciseRegistryProvider._()
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

/// The word and bundle [selectPair] picks; null when no card is due. Builds
/// no exercise, so it is cheap enough to watch from the home screen.

@ProviderFor(nextGrammarPair)
const nextGrammarPairProvider = NextGrammarPairProvider._();

/// The word and bundle [selectPair] picks; null when no card is due. Builds
/// no exercise, so it is cheap enough to watch from the home screen.

final class NextGrammarPairProvider
    extends
        $FunctionalProvider<
          AsyncValue<SelectedPair?>,
          SelectedPair?,
          FutureOr<SelectedPair?>
        >
    with $FutureModifier<SelectedPair?>, $FutureProvider<SelectedPair?> {
  /// The word and bundle [selectPair] picks; null when no card is due. Builds
  /// no exercise, so it is cheap enough to watch from the home screen.
  const NextGrammarPairProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextGrammarPairProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextGrammarPairHash();

  @$internal
  @override
  $FutureProviderElement<SelectedPair?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SelectedPair?> create(Ref ref) {
    return nextGrammarPair(ref);
  }
}

String _$nextGrammarPairHash() => r'650034d0d9bcb4fb6277587bee3ffe8a88c3d9a7';

/// The next grammar exercise: the pair of [nextGrammarPair], asked in a kind
/// that fits the stability of its weaker card. Null when no card is due.

@ProviderFor(nextGrammarExercise)
const nextGrammarExerciseProvider = NextGrammarExerciseProvider._();

/// The next grammar exercise: the pair of [nextGrammarPair], asked in a kind
/// that fits the stability of its weaker card. Null when no card is due.

final class NextGrammarExerciseProvider
    extends
        $FunctionalProvider<
          AsyncValue<GrammarExercise?>,
          GrammarExercise?,
          FutureOr<GrammarExercise?>
        >
    with $FutureModifier<GrammarExercise?>, $FutureProvider<GrammarExercise?> {
  /// The next grammar exercise: the pair of [nextGrammarPair], asked in a kind
  /// that fits the stability of its weaker card. Null when no card is due.
  const NextGrammarExerciseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextGrammarExerciseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextGrammarExerciseHash();

  @$internal
  @override
  $FutureProviderElement<GrammarExercise?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GrammarExercise?> create(Ref ref) {
    return nextGrammarExercise(ref);
  }
}

String _$nextGrammarExerciseHash() =>
    r'04a261d7a38d387295de9cb0f90d0b6cd68e49a4';

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.

@ProviderFor(translationChoices)
const translationChoicesProvider = TranslationChoicesFamily._();

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
  const TranslationChoicesProvider._({
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
    r'50cfd3b0eced1c41f679ec323bf54e58bdad5b34';

/// Provides shuffled translation choices for a practice item:
/// the correct translation plus 3 distractors from the chosen strategy.

final class TranslationChoicesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, PracticeItem> {
  const TranslationChoicesFamily._()
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
