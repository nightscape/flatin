import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/rewards.dart';
import '../models/reward.dart';
import '../services/reward_storage.dart';

part 'reward_provider.g.dart';

@riverpod
class Rewards extends _$Rewards {
  @override
  Future<RewardLedger> build() => RewardStorage.load();

  /// Runs every strategy on the same ledger, applies all effects, saves once.
  Future<List<RewardEffect>> send(RewardEvent event) async {
    final ledger = await future;
    final effects = [
      for (final strategy in rewardStrategies)
        ...strategy.onEvent(event, ledger),
    ];
    final updated = effects.fold(ledger, (l, e) => l.apply(e));
    await RewardStorage.save(updated);
    state = AsyncData(updated);
    return effects;
  }

  Future<void> buy(Building building) async {
    final ledger = await future;
    assert(!ledger.buildings.contains(building.id), '${building.id} is built');
    final updated = ledger
        .apply(CoinsSpent(building.price))
        .apply(BuildingAdded(building.id));
    await RewardStorage.save(updated);
    state = AsyncData(updated);
  }
}
