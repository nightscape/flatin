import '../models/reward.dart';

const double townWidth = 1024;
const double townHeight = 875;

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

/// Counting practice days is calendar logic, not a game rule, so it is code.
/// It counts days, never a streak.
List<DayCounted> countDay(RewardLedger ledger, RewardEvent event) =>
    switch (event) {
      Answered(:final at) when _day(at) != ledger.lastPracticeDay => [
        DayCounted(_day(at)),
      ],
      _ => const [],
    };

String _day(DateTime at) {
  assert(!at.isUtc, 'practice days are local');
  return '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}

/// The settings keys of the rewards the learner can switch off.
const List<String> switchableRewardIds = ['points', 'town'];
