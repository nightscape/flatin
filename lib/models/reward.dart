/// The resource the screens show.
const String coins = 'coins';

/// An event carries facts only; the game rules give them their meaning.
sealed class RewardEvent {
  const RewardEvent();

  /// The values the rules' `when` and `per` read, keyed as in
  /// [rewardEventFields].
  Map<String, Object?> get facts;
}

final class Answered extends RewardEvent {
  final bool right;
  final bool firstAttempt;

  /// The FSRS difficulty of the task's word card before this round reviewed
  /// it; null when the card was never reviewed.
  final double? wordDifficulty;

  /// The [ExerciseKind] name.
  final String kind;
  final String dataFile;
  final DateTime at;

  const Answered({
    required this.right,
    required this.firstAttempt,
    required this.wordDifficulty,
    required this.kind,
    required this.dataFile,
    required this.at,
  });

  @override
  Map<String, Object?> get facts => {
    'right': right,
    'firstAttempt': firstAttempt,
    'wordDifficulty': wordDifficulty,
    'kind': kind,
    'dataFile': dataFile,
  };
}

final class RoundFinished extends RewardEvent {
  const RoundFinished();

  @override
  Map<String, Object?> get facts => const {};
}

/// One check in the noun, verb or word classification practice with [right]
/// correct choices.
final class ChoicesChecked extends RewardEvent {
  final int right;

  const ChoicesChecked(this.right) : assert(right > 0);

  @override
  Map<String, Object?> get facts => {'right': right};
}

/// The events by their name in the rule file, with the types of their facts.
const Map<String, Map<String, Type>> rewardEventFields = {
  'answered': {
    'right': bool,
    'firstAttempt': bool,
    'wordDifficulty': double,
    'kind': String,
    'dataFile': String,
  },
  'choicesChecked': {'right': int},
  'roundFinished': {},
};

String rewardEventName(RewardEvent event) => switch (event) {
  Answered() => 'answered',
  ChoicesChecked() => 'choicesChecked',
  RoundFinished() => 'roundFinished',
};

sealed class RewardEffect {
  const RewardEffect();
}

/// [tag] marks a share for the statistics, such as `bonus`.
final class ResourceGained extends RewardEffect {
  final String resource;
  final int amount;
  final String? tag;

  const ResourceGained(this.resource, this.amount, {this.tag});
}

final class ResourceSpent extends RewardEffect {
  final String resource;
  final int amount;

  const ResourceSpent(this.resource, this.amount);
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
  /// Per resource, all gains; the balance is this minus [spent].
  final Map<String, int> earned;

  /// Per resource and tag, the part of [earned] gained with that tag.
  final Map<String, Map<String, int>> tagged;
  final Map<String, int> spent;
  final List<String> buildings;
  final int practiceDays;
  final String? lastPracticeDay;

  const RewardLedger({
    this.earned = const {},
    this.tagged = const {},
    this.spent = const {},
    this.buildings = const [],
    this.practiceDays = 0,
    this.lastPracticeDay,
  });

  int earnedOf(String resource) => earned[resource] ?? 0;

  int taggedOf(String resource, String tag) => tagged[resource]?[tag] ?? 0;

  int balance(String resource) => earnedOf(resource) - (spent[resource] ?? 0);

  bool canAfford(Map<String, int> price) =>
      price.entries.every((p) => p.value <= balance(p.key));

  RewardLedger apply(RewardEffect effect) => switch (effect) {
    ResourceGained(:final resource, :final amount, :final tag) => _gain(
      resource,
      amount,
      tag,
    ),
    ResourceSpent(:final resource, :final amount) => _spend(resource, amount),
    BuildingAdded(:final buildingId) => _copy(
      buildings: [...buildings, buildingId],
    ),
    DayCounted(:final day) => _copy(
      practiceDays: practiceDays + 1,
      lastPracticeDay: day,
    ),
  };

  RewardLedger _spend(String resource, int amount) {
    assert(
      amount > 0 && amount <= balance(resource),
      'cannot spend $amount $resource of ${balance(resource)}',
    );
    return _copy(spent: _plus(spent, resource, amount));
  }

  RewardLedger _gain(String resource, int amount, String? tag) {
    assert(amount > 0, 'a gain must be positive: $amount $resource');
    return _copy(
      earned: _plus(earned, resource, amount),
      tagged: tag == null
          ? tagged
          : {...tagged, resource: _plus(tagged[resource] ?? {}, tag, amount)},
    );
  }

  static Map<String, int> _plus(Map<String, int> m, String key, int n) => {
    ...m,
    key: (m[key] ?? 0) + n,
  };

  RewardLedger _copy({
    Map<String, int>? earned,
    Map<String, Map<String, int>>? tagged,
    Map<String, int>? spent,
    List<String>? buildings,
    int? practiceDays,
    String? lastPracticeDay,
  }) => RewardLedger(
    earned: earned ?? this.earned,
    tagged: tagged ?? this.tagged,
    spent: spent ?? this.spent,
    buildings: buildings ?? this.buildings,
    practiceDays: practiceDays ?? this.practiceDays,
    lastPracticeDay: lastPracticeDay ?? this.lastPracticeDay,
  );

  Map<String, Object?> toJson() => {
    'earned': earned,
    'tagged': tagged,
    'spent': spent,
    'buildings': buildings,
    'practiceDays': practiceDays,
    'lastPracticeDay': lastPracticeDay,
  };

  factory RewardLedger.fromJson(Map<String, Object?> json) => RewardLedger(
    earned: Map<String, int>.from(json['earned'] as Map),
    tagged: {
      for (final e in (json['tagged'] as Map).entries)
        e.key as String: Map<String, int>.from(e.value as Map),
    },
    spent: Map<String, int>.from(json['spent'] as Map),
    buildings: List<String>.from(json['buildings'] as List),
    practiceDays: json['practiceDays'] as int,
    lastPracticeDay: json['lastPracticeDay'] as String?,
  );
}
