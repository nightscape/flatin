import 'dart:math';

import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/models/fsrs_card.dart';

/// R from a table, so a test oracle and the providers read the same R
/// whatever the clock says while they run.
final class TableScheduler extends Scheduler {
  TableScheduler(this.r);

  final Map<Card, double> r;

  /// The scheduler of [store]: each card's R from its table.
  factory TableScheduler.of(CardStore store) => TableScheduler(
    Map<Card, double>.identity()..addAll({
      for (final c in store.cards.values) c.card: store.r[c.itemId]!,
    }),
  );

  @override
  double getCardRetrievability(Card card, {DateTime? currentDateTime}) =>
      r[card]!;
}

/// The output of the cards provider and the R of every card.
typedef CardStore = ({
  Map<String, PracticeItemCard> cards,
  Map<String, double> r,
  bool empty,
});

/// Distances of a due date from now: at least a minute, as production reads
/// the clock with no seam and a run takes seconds.
const dueOffsets = [
  Duration(minutes: 1),
  Duration(hours: 1),
  Duration(days: 1),
  Duration(days: 30),
];

/// R values that make ties likely.
const tiedR = [0.05, 0.1, 0.3, 0.5, 0.8, 0.95];

/// A store over the cards of [fresh] (as synced: new and due): empty with
/// chance [emptyChance], else each card kept as synced or drawn: due before
/// or after [now] by one of [dueOffsets] (all due, none due or mixed by
/// case), new or reviewed with random stability and difficulty. R per card
/// from [tiedR] or uniform. Each card is left out with chance [absent], as
/// in a store saved before its item existed. [orphans] more cards copy drawn
/// ones under ids outside [fresh], as in a store saved before their items
/// were renamed or removed.
CardStore drawCardStore(
  Random rng,
  Map<String, PracticeItemCard> fresh,
  DateTime now, {
  double emptyChance = 1 / 6,
  double absent = 0,
  int orphans = 0,
}) {
  T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];
  final empty = rng.nextDouble() < emptyChance;
  final dueMode = rng.nextInt(4);
  final present = pick([1.0, 1.0, 0.5]);
  final newShare = pick([0.0, 0.3, 1.0]);
  final cards = <String, PracticeItemCard>{};
  final r = <String, double>{};
  for (final synced in fresh.values) {
    r[synced.itemId] = rng.nextBool() ? pick(tiedR) : rng.nextDouble();
    // Drawn only when asked for, so the other callers keep their draws.
    if (absent > 0 && rng.nextDouble() < absent) continue;
    if (empty || rng.nextDouble() >= present) {
      cards[synced.itemId] = PracticeItemCard(
        itemId: synced.itemId,
        card: Card(cardId: synced.card.cardId),
        due: synced.due,
      );
      continue;
    }
    final isDue = switch (dueMode) {
      0 => true,
      1 => false,
      _ => rng.nextBool(),
    };
    final offset = pick(dueOffsets);
    final lastReview = rng.nextDouble() < newShare
        ? null
        : now.subtract(const Duration(days: 2));
    cards[synced.itemId] = PracticeItemCard(
      itemId: synced.itemId,
      card: Card(
        cardId: synced.card.cardId,
        state: lastReview == null ? State.learning : State.review,
        stability: lastReview == null ? null : 0.5 + rng.nextDouble() * 60,
        difficulty: lastReview == null ? null : 1 + rng.nextDouble() * 9,
        lastReview: lastReview,
      ),
      lastReview: lastReview,
      due: isDue ? now.subtract(offset) : now.add(offset),
    );
  }
  final kept = [...cards.values];
  for (var i = 0; i < orphans; i++) {
    final like = pick(kept);
    final parts = like.itemId.split(':');
    final id = [
      ...parts.take(parts.first == 'grammar' ? 2 : 1),
      'orphan$i',
    ].join(':');
    cards[id] = PracticeItemCard(
      itemId: id,
      card: Card.fromMap({...like.card.toMap(), 'cardId': id.hashCode}),
      lastReview: like.lastReview,
      due: like.due,
    );
    r[id] = rng.nextDouble();
  }
  return (cards: cards, r: r, empty: empty);
}
