sealed class RewardEvent {
  const RewardEvent();
}

final class Answered extends RewardEvent {
  final bool right;
  final bool firstAttempt;

  /// The FSRS difficulty of the task's word card before this round reviewed
  /// it; null when the card was never reviewed.
  final double? wordDifficulty;
  final DateTime at;

  const Answered({
    required this.right,
    required this.firstAttempt,
    required this.wordDifficulty,
    required this.at,
  });
}

final class RoundFinished extends RewardEvent {
  const RoundFinished();
}

/// One check in the noun, verb or word classification practice with [right]
/// correct choices.
final class ChoicesChecked extends RewardEvent {
  final int right;

  const ChoicesChecked(this.right) : assert(right > 0);
}

sealed class RewardEffect {
  const RewardEffect();
}

final class PointsGained extends RewardEffect {
  final int points;

  const PointsGained(this.points);
}

final class BonusGained extends RewardEffect {
  final int points;

  const BonusGained(this.points);
}

final class BuildingAdded extends RewardEffect {
  final String buildingId;

  const BuildingAdded(this.buildingId);
}

final class CoinsSpent extends RewardEffect {
  final int coins;

  const CoinsSpent(this.coins);
}

/// [day] is a local calendar day as `yyyy-MM-dd`.
final class DayCounted extends RewardEffect {
  final String day;

  const DayCounted(this.day);
}

/// What the learner has earned. Only [apply] changes it, and every effect adds.
final class RewardLedger {
  final int points;

  /// The part of [points] that came from bonuses.
  final int bonusPoints;

  /// The coins paid for buildings; the balance is [points] minus this.
  final int spent;
  final List<String> buildings;
  final int practiceDays;
  final String? lastPracticeDay;

  const RewardLedger({
    this.points = 0,
    this.bonusPoints = 0,
    this.spent = 0,
    this.buildings = const [],
    this.practiceDays = 0,
    this.lastPracticeDay,
  });

  int get balance => points - spent;

  RewardLedger apply(RewardEffect effect) => switch (effect) {
    PointsGained(:final points) => _gain(points, 0),
    BonusGained(:final points) => _gain(points, points),
    BuildingAdded(:final buildingId) => RewardLedger(
      points: points,
      bonusPoints: bonusPoints,
      spent: spent,
      buildings: [...buildings, buildingId],
      practiceDays: practiceDays,
      lastPracticeDay: lastPracticeDay,
    ),
    CoinsSpent(:final coins) => _spend(coins),
    DayCounted(:final day) => RewardLedger(
      points: points,
      bonusPoints: bonusPoints,
      spent: spent,
      buildings: buildings,
      practiceDays: practiceDays + 1,
      lastPracticeDay: day,
    ),
  };

  RewardLedger _spend(int coins) {
    assert(coins > 0 && coins <= balance, 'cannot spend $coins of $balance');
    return RewardLedger(
      points: points,
      bonusPoints: bonusPoints,
      spent: spent + coins,
      buildings: buildings,
      practiceDays: practiceDays,
      lastPracticeDay: lastPracticeDay,
    );
  }

  RewardLedger _gain(int gained, int bonus) {
    assert(gained > 0, 'a point gain must be positive: $gained');
    return RewardLedger(
      points: points + gained,
      bonusPoints: bonusPoints + bonus,
      spent: spent,
      buildings: buildings,
      practiceDays: practiceDays,
      lastPracticeDay: lastPracticeDay,
    );
  }

  Map<String, Object?> toJson() => {
    'points': points,
    'bonusPoints': bonusPoints,
    'spent': spent,
    'buildings': buildings,
    'practiceDays': practiceDays,
    'lastPracticeDay': lastPracticeDay,
  };

  factory RewardLedger.fromJson(Map<String, Object?> json) => RewardLedger(
    points: json['points'] as int,
    bonusPoints: json['bonusPoints'] as int? ?? 0,
    spent: json['spent'] as int? ?? 0,
    buildings: List<String>.from(json['buildings'] as List),
    practiceDays: json['practiceDays'] as int,
    lastPracticeDay: json['lastPracticeDay'] as String?,
  );
}

abstract interface class RewardStrategy {
  /// The settings key: 'points', 'bonus', 'town' or 'days'.
  String get id;

  /// Pure: reads the ledger, never changes it.
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger);
}
