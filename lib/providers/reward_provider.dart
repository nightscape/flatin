import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/game_rules.dart';
import '../data/rewards.dart';
import '../models/reward.dart';
import '../services/reward_storage.dart';

part 'reward_provider.g.dart';

@riverpod
Future<GameRules> gameRules(Ref ref) => loadGameRules();

/// Loads after [gameRulesProvider], so a screen that has the ledger also has
/// the rules.
@riverpod
class Rewards extends _$Rewards {
  @override
  Future<RewardLedger> build() async {
    await ref.watch(gameRulesProvider.future);
    return RewardStorage.load();
  }

  /// Applies the rules' gains and the day count, saves once.
  Future<List<RewardEffect>> send(RewardEvent event) async {
    final ledger = await future;
    final rules = await ref.read(gameRulesProvider.future);
    return _apply(ledger, [
      ...rules.gainsOf(ledger, event),
      ...countDay(ledger, event),
    ]);
  }

  Future<void> buy(Building building) async {
    final ledger = await future;
    assert(!ledger.buildings.contains(building.id), '${building.id} is built');
    final rules = await ref.read(gameRulesProvider.future);
    await _apply(ledger, rules.buy(ledger, building));
  }

  Future<List<RewardEffect>> _apply(
    RewardLedger ledger,
    List<RewardEffect> effects,
  ) async {
    final updated = effects.fold(ledger, (l, e) => l.apply(e));
    await RewardStorage.save(updated);
    state = AsyncData(updated);
    return effects;
  }
}
