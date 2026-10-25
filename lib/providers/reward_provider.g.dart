// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Rewards)
const rewardsProvider = RewardsProvider._();

final class RewardsProvider
    extends $AsyncNotifierProvider<Rewards, RewardLedger> {
  const RewardsProvider._()
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

String _$rewardsHash() => r'e66d82191461362ba3ec3fbe87b2fc90fe6c56d0';

abstract class _$Rewards extends $AsyncNotifier<RewardLedger> {
  FutureOr<RewardLedger> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<RewardLedger>, RewardLedger>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RewardLedger>, RewardLedger>,
              AsyncValue<RewardLedger>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
