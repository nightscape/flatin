// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gameRules)
final gameRulesProvider = GameRulesProvider._();

final class GameRulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<GameRules>,
          GameRules,
          FutureOr<GameRules>
        >
    with $FutureModifier<GameRules>, $FutureProvider<GameRules> {
  GameRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameRulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameRulesHash();

  @$internal
  @override
  $FutureProviderElement<GameRules> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<GameRules> create(Ref ref) {
    return gameRules(ref);
  }
}

String _$gameRulesHash() => r'07184b407cbff0ea98dd86ff1bff0431cac537b7';

/// Loads after [gameRulesProvider], so a screen that has the ledger also has
/// the rules.

@ProviderFor(Rewards)
final rewardsProvider = RewardsProvider._();

/// Loads after [gameRulesProvider], so a screen that has the ledger also has
/// the rules.
final class RewardsProvider
    extends $AsyncNotifierProvider<Rewards, RewardLedger> {
  /// Loads after [gameRulesProvider], so a screen that has the ledger also has
  /// the rules.
  RewardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rewardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rewardsHash();

  @$internal
  @override
  Rewards create() => Rewards();
}

String _$rewardsHash() => r'4f6756eab645f8bb8ddb6b473b62de488f975aed';

/// Loads after [gameRulesProvider], so a screen that has the ledger also has
/// the rules.

abstract class _$Rewards extends $AsyncNotifier<RewardLedger> {
  FutureOr<RewardLedger> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RewardLedger>, RewardLedger>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RewardLedger>, RewardLedger>,
              AsyncValue<RewardLedger>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
