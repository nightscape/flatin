// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Generic notifier for managing practice screen state

@ProviderFor(PracticeNotifier)
const practiceProvider = PracticeNotifierFamily._();

/// Generic notifier for managing practice screen state
final class PracticeNotifierProvider
    extends $NotifierProvider<PracticeNotifier, PracticeState> {
  /// Generic notifier for managing practice screen state
  const PracticeNotifierProvider._({
    required PracticeNotifierFamily super.from,
    required PracticeItem super.argument,
  }) : super(
         retry: null,
         name: r'practiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$practiceNotifierHash();

  @override
  String toString() {
    return r'practiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PracticeNotifier create() => PracticeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PracticeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PracticeState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PracticeNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$practiceNotifierHash() => r'da6dae1f4b2672f62474fb6ae81bdded77c86454';

/// Generic notifier for managing practice screen state

final class PracticeNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PracticeNotifier,
          PracticeState,
          PracticeState,
          PracticeState,
          PracticeItem
        > {
  const PracticeNotifierFamily._()
    : super(
        retry: null,
        name: r'practiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Generic notifier for managing practice screen state

  PracticeNotifierProvider call(PracticeItem item) =>
      PracticeNotifierProvider._(argument: item, from: this);

  @override
  String toString() => r'practiceProvider';
}

/// Generic notifier for managing practice screen state

abstract class _$PracticeNotifier extends $Notifier<PracticeState> {
  late final _$args = ref.$arg as PracticeItem;
  PracticeItem get item => _$args;

  PracticeState build(PracticeItem item);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<PracticeState, PracticeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PracticeState, PracticeState>,
              PracticeState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for word classification state

@ProviderFor(WordClassificationNotifier)
const wordClassificationProvider = WordClassificationNotifierProvider._();

/// Provider for word classification state
final class WordClassificationNotifierProvider
    extends
        $NotifierProvider<WordClassificationNotifier, WordClassificationState> {
  /// Provider for word classification state
  const WordClassificationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordClassificationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordClassificationNotifierHash();

  @$internal
  @override
  WordClassificationNotifier create() => WordClassificationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordClassificationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordClassificationState>(value),
    );
  }
}

String _$wordClassificationNotifierHash() =>
    r'4b97bd41c2a3e59446790639d2caae274a75dcb6';

/// Provider for word classification state

abstract class _$WordClassificationNotifier
    extends $Notifier<WordClassificationState> {
  WordClassificationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<WordClassificationState, WordClassificationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WordClassificationState, WordClassificationState>,
              WordClassificationState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
