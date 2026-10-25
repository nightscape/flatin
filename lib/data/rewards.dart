import '../models/reward.dart';

const double townWidth = 1024;
const double townHeight = 765;

/// Position in fractions of the town background: horizontal centre, bottom edge, width.
typedef Building = ({String id, double x, double bottom, double width});

/// The build steps of stage 1, in the order they are earned.
const List<Building> romanTown = [
  (
    id: 'domus',
    x: 300 / townWidth,
    bottom: 400 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'hortus',
    x: 410 / townWidth,
    bottom: 370 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'fons',
    x: 420 / townWidth,
    bottom: 470 / townHeight,
    width: 80 / townWidth,
  ),
  (
    id: 'taberna',
    x: 520 / townWidth,
    bottom: 450 / townHeight,
    width: 80 / townWidth,
  ),
  (
    id: 'villa',
    x: 640 / townWidth,
    bottom: 330 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'templum',
    x: 520 / townWidth,
    bottom: 330 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'ager',
    x: 840 / townWidth,
    bottom: 260 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'vinea',
    x: 960 / townWidth,
    bottom: 280 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'stabulum',
    x: 760 / townWidth,
    bottom: 420 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'figlina',
    x: 880 / townWidth,
    bottom: 520 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'pistrinum',
    x: 640 / townWidth,
    bottom: 520 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'aquaeductus',
    x: 560 / townWidth,
    bottom: 230 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'thermae',
    x: 330 / townWidth,
    bottom: 540 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'statua',
    x: 470 / townWidth,
    bottom: 560 / townHeight,
    width: 80 / townWidth,
  ),
  (
    id: 'portus',
    x: 150 / townWidth,
    bottom: 460 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'navis',
    x: 70 / townWidth,
    bottom: 560 / townHeight,
    width: 110 / townWidth,
  ),
  (
    id: 'murus',
    x: 210 / townWidth,
    bottom: 330 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'castra',
    x: 720 / townWidth,
    bottom: 650 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'bibliotheca',
    x: 560 / townWidth,
    bottom: 640 / townHeight,
    width: 140 / townWidth,
  ),
  (
    id: 'amphitheatrum',
    x: 360 / townWidth,
    bottom: 700 / townHeight,
    width: 190 / townWidth,
  ),
];

/// Distinct built buildings in step order; ledgers may hold repeated ids.
List<Building> townOf(RewardLedger ledger) => [
  for (final b in romanTown)
    if (ledger.buildings.contains(b.id)) b,
];

/// The first step not built yet, null when the town is complete.
Building? nextBuilding(RewardLedger ledger) =>
    romanTown.where((b) => !ledger.buildings.contains(b.id)).firstOrNull;

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

/// One building per round until the town is complete.
class TownStrategy implements RewardStrategy {
  const TownStrategy();

  @override
  String get id => 'town';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      switch (event) {
        RoundFinished() => [
          if (nextBuilding(ledger) case final next?) BuildingAdded(next.id),
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
