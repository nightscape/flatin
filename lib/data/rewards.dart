import '../models/reward.dart';

const double townWidth = 1024;
const double townHeight = 875;

typedef Building = ({String id, int price});

const int _small = 250;
const int _middle = 400;
const int _large = 600;

/// The buildings of stage 1 with their prices in coins: about 30 minutes of
/// practice for a middle one.
const List<Building> romanTown = [
  (id: 'domus', price: _middle),
  (id: 'hortus', price: _small),
  (id: 'fons', price: _small),
  (id: 'taberna', price: _middle),
  (id: 'villa', price: _middle),
  (id: 'templum', price: _large),
  (id: 'ager', price: _small),
  (id: 'vinea', price: _small),
  (id: 'stabulum', price: _middle),
  (id: 'figlina', price: _middle),
  (id: 'pistrinum', price: _middle),
  (id: 'aquaeductus', price: _large),
  (id: 'thermae', price: _large),
  (id: 'statua', price: _small),
  (id: 'portus', price: _large),
  (id: 'navis', price: _middle),
  (id: 'murus', price: _middle),
  (id: 'castra', price: _large),
  (id: 'bibliotheca', price: _middle),
  (id: 'amphitheatrum', price: _large),
];

/// An image of a building placed on the town background, in fractions of its size:
/// left edge, width and bottom edge (the height follows from the image).
typedef TownSprite = ({
  String sprite,
  String building,
  double left,
  double width,
  double bottom,
});

/// All sprites in paint order, back to front; the aqueduct consists of several.
const List<TownSprite> townSprites = [
  (
    sprite: 'aquaeductus-0',
    building: 'aquaeductus',
    left: 0.4639,
    width: 0.0586,
    bottom: 0.2629,
  ),
  (
    sprite: 'aquaeductus-1',
    building: 'aquaeductus',
    left: 0.5225,
    width: 0.0586,
    bottom: 0.3017,
  ),
  (
    sprite: 'ager',
    building: 'ager',
    left: 0.3975,
    width: 0.1045,
    bottom: 0.3349,
  ),
  (
    sprite: 'aquaeductus-2',
    building: 'aquaeductus',
    left: 0.5811,
    width: 0.0586,
    bottom: 0.336,
  ),
  (
    sprite: 'vinea',
    building: 'vinea',
    left: 0.4678,
    width: 0.1045,
    bottom: 0.3829,
  ),
  (
    sprite: 'stabulum',
    building: 'stabulum',
    left: 0.3223,
    width: 0.1045,
    bottom: 0.3863,
  ),
  (
    sprite: 'aquaeductus-3',
    building: 'aquaeductus',
    left: 0.6396,
    width: 0.0586,
    bottom: 0.3749,
  ),
  (
    sprite: 'hortus',
    building: 'hortus',
    left: 0.5381,
    width: 0.1045,
    bottom: 0.4297,
  ),
  (
    sprite: 'figlina',
    building: 'figlina',
    left: 0.3926,
    width: 0.1045,
    bottom: 0.4343,
  ),
  (
    sprite: 'aquaeductus-4',
    building: 'aquaeductus',
    left: 0.6982,
    width: 0.0586,
    bottom: 0.4206,
  ),
  (
    sprite: 'castra',
    building: 'castra',
    left: 0.207,
    width: 0.1279,
    bottom: 0.4811,
  ),
  (
    sprite: 'aquaeductus-5',
    building: 'aquaeductus',
    left: 0.7568,
    width: 0.0586,
    bottom: 0.4594,
  ),
  (
    sprite: 'pistrinum',
    building: 'pistrinum',
    left: 0.4629,
    width: 0.1045,
    bottom: 0.4811,
  ),
  (
    sprite: 'templum',
    building: 'templum',
    left: 0.6377,
    width: 0.1279,
    bottom: 0.5211,
  ),
  (
    sprite: 'aquaeductus-6',
    building: 'aquaeductus',
    left: 0.8154,
    width: 0.0352,
    bottom: 0.4834,
  ),
  (
    sprite: 'taberna',
    building: 'taberna',
    left: 0.3242,
    width: 0.0811,
    bottom: 0.5131,
  ),
  (
    sprite: 'castellum',
    building: 'aquaeductus',
    left: 0.8096,
    width: 0.1338,
    bottom: 0.5497,
  ),
  (
    sprite: 'bibliotheca',
    building: 'bibliotheca',
    left: 0.5625,
    width: 0.1279,
    bottom: 0.5714,
  ),
  (
    sprite: 'villa',
    building: 'villa',
    left: 0.7139,
    width: 0.1279,
    bottom: 0.5794,
  ),
  (
    sprite: 'portus',
    building: 'portus',
    left: 0.2139,
    width: 0.1045,
    bottom: 0.5714,
  ),
  (
    sprite: 'fons',
    building: 'fons',
    left: 0.3594,
    width: 0.0811,
    bottom: 0.568,
  ),
  (
    sprite: 'statua',
    building: 'statua',
    left: 0.6504,
    width: 0.0811,
    bottom: 0.5989,
  ),
  (
    sprite: 'thermae',
    building: 'thermae',
    left: 0.459,
    width: 0.1279,
    bottom: 0.6354,
  ),
  (
    sprite: 'domus',
    building: 'domus',
    left: 0.7031,
    width: 0.1045,
    bottom: 0.6503,
  ),
  (
    sprite: 'murus',
    building: 'murus',
    left: 0.3779,
    width: 0.1279,
    bottom: 0.6823,
  ),
  (
    sprite: 'amphitheatrum',
    building: 'amphitheatrum',
    left: 0.4941,
    width: 0.1973,
    bottom: 0.7291,
  ),
  (
    sprite: 'navis',
    building: 'navis',
    left: 0.3135,
    width: 0.1045,
    bottom: 0.7097,
  ),
];

/// Distinct built buildings in step order; ledgers may hold repeated ids.
List<Building> townOf(RewardLedger ledger) => [
  for (final b in romanTown)
    if (ledger.buildings.contains(b.id)) b,
];

/// The buildings the shop offers, in step order.
List<Building> unbuiltOf(RewardLedger ledger) => [
  for (final b in romanTown)
    if (!ledger.buildings.contains(b.id)) b,
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

/// Buildings are bought in the shop, so no event adds one; this id only
/// switches the town on and off.
class TownStrategy implements RewardStrategy {
  const TownStrategy();

  @override
  String get id => 'town';

  @override
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger) =>
      const [];
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
