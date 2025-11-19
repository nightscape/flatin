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

/// Provider for all FSRS cards (synced with YAML items)

@ProviderFor(fsrsCards)
const fsrsCardsProvider = FsrsCardsProvider._();

/// Provider for all FSRS cards (synced with YAML items)

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
  /// Provider for all FSRS cards (synced with YAML items)
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

String _$fsrsCardsHash() => r'c22cda206b74e010595ed1c9bbe2d695ea4e589d';

/// Provider for due cards

@ProviderFor(dueCards)
const dueCardsProvider = DueCardsProvider._();

/// Provider for due cards

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
  /// Provider for due cards
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

String _$dueCardsHash() => r'dfe7b43bb0a8a1d79b7a8140b4baceedcd310365';

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

String _$dueItemsByTypeHash() => r'e521d57c77fdbb4be84774d29cd1bfe5d6b967d4';

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
