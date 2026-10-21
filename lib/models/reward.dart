sealed class RewardEvent {
  const RewardEvent();
}

final class Answered extends RewardEvent {
  final bool right;
  final bool firstAttempt;
  final DateTime at;

  const Answered({
    required this.right,
    required this.firstAttempt,
    required this.at,
  });
}

final class RoundFinished extends RewardEvent {
  const RoundFinished();
}

sealed class RewardEffect {
  const RewardEffect();
}

final class PointsGained extends RewardEffect {
  final int points;

  const PointsGained(this.points);
}

final class BuildingAdded extends RewardEffect {
  final String buildingId;

  const BuildingAdded(this.buildingId);
}

/// [day] is a local calendar day as `yyyy-MM-dd`.
final class DayCounted extends RewardEffect {
  final String day;

  const DayCounted(this.day);
}

/// What the learner has earned. Only [apply] changes it, and every effect adds.
final class RewardLedger {
  final int points;
  final List<String> buildings;
  final int practiceDays;
  final String? lastPracticeDay;

  const RewardLedger({
    this.points = 0,
    this.buildings = const [],
    this.practiceDays = 0,
    this.lastPracticeDay,
  });

  RewardLedger apply(RewardEffect effect) => switch (effect) {
    PointsGained(:final points) => _gain(points),
    BuildingAdded(:final buildingId) => RewardLedger(
      points: points,
      buildings: [...buildings, buildingId],
      practiceDays: practiceDays,
      lastPracticeDay: lastPracticeDay,
    ),
    DayCounted(:final day) => RewardLedger(
      points: points,
      buildings: buildings,
      practiceDays: practiceDays + 1,
      lastPracticeDay: day,
    ),
  };

  RewardLedger _gain(int gained) {
    assert(gained > 0, 'PointsGained must be positive: $gained');
    return RewardLedger(
      points: points + gained,
      buildings: buildings,
      practiceDays: practiceDays,
      lastPracticeDay: lastPracticeDay,
    );
  }

  Map<String, Object?> toJson() => {
    'points': points,
    'buildings': buildings,
    'practiceDays': practiceDays,
    'lastPracticeDay': lastPracticeDay,
  };

  factory RewardLedger.fromJson(Map<String, Object?> json) => RewardLedger(
    points: json['points'] as int,
    buildings: List<String>.from(json['buildings'] as List),
    practiceDays: json['practiceDays'] as int,
    lastPracticeDay: json['lastPracticeDay'] as String?,
  );
}

abstract interface class RewardStrategy {
  /// The settings key: 'points', 'town' or 'days'.
  String get id;

  /// Pure: reads the ledger, never changes it.
  List<RewardEffect> onEvent(RewardEvent event, RewardLedger ledger);
}
