import 'dart:math';

import 'practice_item.dart';

/// Chooses the wrong translations offered next to the correct one.
abstract interface class DistractorStrategy {
  String get id;

  /// Exactly [count] distinct translations from [pool], none equal to
  /// [item]'s own; throws when [pool] has too few.
  List<String> pick(
    PracticeItem item,
    List<PracticeItem> pool,
    int count,
    Random rng,
  );
}

const defaultDistractorStrategyId = 'random';

final List<DistractorStrategy> distractorStrategies = [RandomDistractors()];

DistractorStrategy distractorStrategyById(String id) =>
    distractorStrategies.singleWhere((s) => s.id == id);

class RandomDistractors implements DistractorStrategy {
  @override
  String get id => 'random';

  @override
  List<String> pick(
    PracticeItem item,
    List<PracticeItem> pool,
    int count,
    Random rng,
  ) {
    final others = {
      for (final i in pool)
        if (i.translation != item.translation) i.translation,
    }.toList()..shuffle(rng);
    if (others.length < count) {
      throw StateError(
        'only ${others.length} distinct translations for $count distractors',
      );
    }
    return others.take(count).toList();
  }
}
