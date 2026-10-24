import '../models/reward.dart';

typedef Building = ({String id, String emoji});

const List<Building> romanTown = [
  (id: 'domus', emoji: '🏠'),
  (id: 'hortus', emoji: '🌳'),
  (id: 'fons', emoji: '⛲'),
  (id: 'taberna', emoji: '🏪'),
  (id: 'villa', emoji: '🏡'),
  (id: 'templum', emoji: '🏛️'),
  (id: 'ager', emoji: '🌾'),
  (id: 'vinea', emoji: '🍇'),
  (id: 'stabulum', emoji: '🐎'),
  (id: 'figlina', emoji: '🏺'),
  (id: 'pistrinum', emoji: '🍞'),
  (id: 'aquaeductus', emoji: '🌉'),
  (id: 'thermae', emoji: '🛁'),
  (id: 'statua', emoji: '🗿'),
  (id: 'portus', emoji: '⚓'),
  (id: 'navis', emoji: '⛵'),
  (id: 'murus', emoji: '🧱'),
  (id: 'castra', emoji: '⛺'),
  (id: 'bibliotheca', emoji: '📜'),
  (id: 'amphitheatrum', emoji: '🏟️'),
];

class PointsStrategy implements RewardStrategy {
  const PointsStrategy();

  @override
  String get id => 'points';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      switch (event) {
        Answered(right: true, :final firstAttempt) => [
          PointsGained(firstAttempt ? 10 : 5),
        ],
        _ => const [],
      };
}

/// The base points again for a word whose card was hard before this round.
class HardWordBonusStrategy implements RewardStrategy {
  const HardWordBonusStrategy();

  static const double minDifficulty = 7;

  @override
  String get id => 'bonus';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      switch (event) {
        Answered(right: true, :final firstAttempt, :final wordDifficulty?)
            when wordDifficulty >= minDifficulty =>
          [BonusGained(firstAttempt ? 10 : 5)],
        _ => const [],
      };
}

/// After the last building the list starts again.
class TownStrategy implements RewardStrategy {
  const TownStrategy();

  @override
  String get id => 'town';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      switch (event) {
        RoundFinished() => [
          BuildingAdded(
            romanTown[ledger.buildings.length % romanTown.length].id,
          ),
        ],
        _ => const [],
      };
}

/// Counts days, never a streak.
class PracticeDaysStrategy implements RewardStrategy {
  const PracticeDaysStrategy();

  @override
  String get id => 'days';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      switch (event) {
        Answered(:final at) when _day(at) != ledger.lastPracticeDay => [
          DayCounted(_day(at)),
        ],
        _ => const [],
      };

  static String _day(DateTime at) {
    assert(!at.isUtc, 'practice days are local');
    return '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }
}

const List<RewardStrategy> rewardStrategies = [
  PointsStrategy(),
  HardWordBonusStrategy(),
  TownStrategy(),
  PracticeDaysStrategy(),
];

/// The strategies the learner can switch off; counting days is always on.
final List<String> switchableRewardIds = [
  for (final s in rewardStrategies)
    if (s is! PracticeDaysStrategy && s is! HardWordBonusStrategy) s.id,
];
