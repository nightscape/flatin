// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The topics the course offers now, in course order.

@ProviderFor(topics)
final topicsProvider = TopicsProvider._();

/// The topics the course offers now, in course order.

final class TopicsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Topic>>,
          List<Topic>,
          FutureOr<List<Topic>>
        >
    with $FutureModifier<List<Topic>>, $FutureProvider<List<Topic>> {
  /// The topics the course offers now, in course order.
  TopicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicsHash();

  @$internal
  @override
  $FutureProviderElement<List<Topic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Topic>> create(Ref ref) {
    return topics(ref);
  }
}

String _$topicsHash() => r'a6e4800b4c166e691a0ad6a13d56951d2173837e';

@ProviderFor(todayOffer)
final todayOfferProvider = TodayOfferProvider._();

final class TodayOfferProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayOffer>,
          TodayOffer,
          FutureOr<TodayOffer>
        >
    with $FutureModifier<TodayOffer>, $FutureProvider<TodayOffer> {
  TodayOfferProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayOfferProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayOfferHash();

  @$internal
  @override
  $FutureProviderElement<TodayOffer> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TodayOffer> create(Ref ref) {
    return todayOffer(ref);
  }
}

String _$todayOfferHash() => r'8acb5080c7ebe00e292c4887f7a326596ffd51f0';

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.

@ProviderFor(Round)
final roundProvider = RoundFamily._();

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.
final class RoundProvider extends $AsyncNotifierProvider<Round, RoundState> {
  /// One round. Auto-dispose and never stored: leaving it aborts it, which
  /// keeps the word reviews already written and reviews no bundle.
  RoundProvider._({
    required RoundFamily super.from,
    required RoundRequest super.argument,
  }) : super(
         retry: null,
         name: r'roundProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roundHash();

  @override
  String toString() {
    return r'roundProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Round create() => Round();

  @override
  bool operator ==(Object other) {
    return other is RoundProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roundHash() => r'd6d169cbe0edf509ad4233baf5d5ae6757d5b008';

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.

final class RoundFamily extends $Family
    with
        $ClassFamilyOverride<
          Round,
          AsyncValue<RoundState>,
          RoundState,
          FutureOr<RoundState>,
          RoundRequest
        > {
  RoundFamily._()
    : super(
        retry: null,
        name: r'roundProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One round. Auto-dispose and never stored: leaving it aborts it, which
  /// keeps the word reviews already written and reviews no bundle.

  RoundProvider call(RoundRequest request) =>
      RoundProvider._(argument: request, from: this);

  @override
  String toString() => r'roundProvider';
}

/// One round. Auto-dispose and never stored: leaving it aborts it, which
/// keeps the word reviews already written and reviews no bundle.

abstract class _$Round extends $AsyncNotifier<RoundState> {
  late final _$args = ref.$arg as RoundRequest;
  RoundRequest get request => _$args;

  FutureOr<RoundState> build(RoundRequest request);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RoundState>, RoundState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RoundState>, RoundState>,
              AsyncValue<RoundState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
