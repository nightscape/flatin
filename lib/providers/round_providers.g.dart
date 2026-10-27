// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The topics the course offers now with words of [focus], in course order.

@ProviderFor(topics)
final topicsProvider = TopicsFamily._();

/// The topics the course offers now with words of [focus], in course order.

final class TopicsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Topic>>,
          List<Topic>,
          FutureOr<List<Topic>>
        >
    with $FutureModifier<List<Topic>>, $FutureProvider<List<Topic>> {
  /// The topics the course offers now with words of [focus], in course order.
  TopicsProvider._({
    required TopicsFamily super.from,
    required WordFocus super.argument,
  }) : super(
         retry: null,
         name: r'topicsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$topicsHash();

  @override
  String toString() {
    return r'topicsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Topic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Topic>> create(Ref ref) {
    final argument = this.argument as WordFocus;
    return topics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TopicsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$topicsHash() => r'bcc1fe93b8d1837c5a839987c75326a6bc36923f';

/// The topics the course offers now with words of [focus], in course order.

final class TopicsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Topic>>, WordFocus> {
  TopicsFamily._()
    : super(
        retry: null,
        name: r'topicsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The topics the course offers now with words of [focus], in course order.

  TopicsProvider call(WordFocus focus) =>
      TopicsProvider._(argument: focus, from: this);

  @override
  String toString() => r'topicsProvider';
}

@ProviderFor(todayOffer)
final todayOfferProvider = TodayOfferFamily._();

final class TodayOfferProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayOffer>,
          TodayOffer,
          FutureOr<TodayOffer>
        >
    with $FutureModifier<TodayOffer>, $FutureProvider<TodayOffer> {
  TodayOfferProvider._({
    required TodayOfferFamily super.from,
    required WordFocus super.argument,
  }) : super(
         retry: null,
         name: r'todayOfferProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$todayOfferHash();

  @override
  String toString() {
    return r'todayOfferProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TodayOffer> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TodayOffer> create(Ref ref) {
    final argument = this.argument as WordFocus;
    return todayOffer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TodayOfferProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$todayOfferHash() => r'1f3d3d27ae6bb1f87ab4a0e516c6385dd0dd2e9a';

final class TodayOfferFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TodayOffer>, WordFocus> {
  TodayOfferFamily._()
    : super(
        retry: null,
        name: r'todayOfferProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TodayOfferProvider call(WordFocus focus) =>
      TodayOfferProvider._(argument: focus, from: this);

  @override
  String toString() => r'todayOfferProvider';
}

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

String _$roundHash() => r'21701506a8621e0c35a808fc98cd4b5030235094';

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
