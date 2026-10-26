import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/models/reward.dart';

/// The rules the rule file encodes, written out by hand.
const _prices = {
  'domus': 400,
  'hortus': 250,
  'fons': 250,
  'taberna': 400,
  'villa': 400,
  'templum': 600,
  'ager': 250,
  'vinea': 250,
  'stabulum': 400,
  'figlina': 400,
  'pistrinum': 400,
  'aquaeductus': 600,
  'thermae': 600,
  'statua': 250,
  'portus': 600,
  'navis': 400,
  'murus': 400,
  'castra': 600,
  'bibliotheca': 400,
  'amphitheatrum': 600,
};

/// Coins and the bonus share of them.
(int, int) _reference(RewardEvent event) => switch (event) {
  Answered(right: true, :final firstAttempt, :final wordDifficulty) => (
    (firstAttempt ? 10 : 5) *
        (wordDifficulty != null && wordDifficulty >= 7 ? 2 : 1),
    wordDifficulty != null && wordDifficulty >= 7 ? (firstAttempt ? 10 : 5) : 0,
  ),
  ChoicesChecked(:final right) => (3 * right, 0),
  _ => (0, 0),
};

typedef _Snapshot = ({int balance, int earned, int bonus, String buildings});

_Snapshot _of(RewardLedger l) => (
  balance: l.balance(coins),
  earned: l.earnedOf(coins),
  bonus: l.taggedOf(coins, 'bonus'),
  buildings: l.buildings.join(' '),
);

/// A step of a sequence: an event, or a purchase of the [buy]th affordable
/// building.
typedef _Step = ({RewardEvent? event, int? buy});

List<_Step> _sequence(Random random) {
  var at = DateTime(2026, 1, 1, 8);
  return [
    for (var i = 0; i < 80; i++)
      switch (random.nextInt(10)) {
        0 => (event: const RoundFinished(), buy: null),
        1 || 2 => (event: ChoicesChecked(1 + random.nextInt(20)), buy: null),
        3 => (event: null, buy: random.nextInt(20)),
        _ => () {
          at = at.add(Duration(hours: random.nextInt(30) - 2));
          final right = random.nextBool();
          final first = random.nextBool();
          final difficulty = switch (random.nextInt(4)) {
            0 => null,
            1 => random.nextDouble() * 7,
            2 => 7.0,
            _ => 7 + random.nextDouble() * 3,
          };
          return (
            event: Answered(
              right: right,
              firstAttempt: first,
              wordDifficulty: difficulty,
              kind: 'deLatWahl',
              dataFile: 'latin_nouns',
              at: at,
            ),
            buy: null,
          );
        }(),
      },
  ];
}

void main() {
  final rules = GameRules.parse(
    File(gameRulesAsset).readAsStringSync(),
    gameRulesAsset,
  );

  test('the rule file lists the buildings with their prices in order', () {
    expect(
      [for (final b in rules.buildings) (b.id, b.price[coins])],
      [for (final e in _prices.entries) (e.key, e.value)],
    );
  });

  test('the rule file and the reference agree after every event', () {
    var steps = 0;
    for (var seed = 0; seed < 600; seed++) {
      var ledger = const RewardLedger();
      var expected = (balance: 0, earned: 0, bonus: 0, buildings: '');
      for (final step in _sequence(Random(seed))) {
        steps++;
        if (step.buy case final pick?) {
          final built = expected.buildings.split(' ');
          final offer = [
            for (final e in _prices.entries)
              if (!built.contains(e.key) && e.value <= expected.balance) e,
          ];
          if (offer.isEmpty) continue;
          final bought = offer[pick % offer.length];
          ledger = rules
              .buy(rules.buildings.singleWhere((b) => b.id == bought.key))
              .fold(ledger, (l, e) => l.apply(e));
          expected = (
            balance: expected.balance - bought.value,
            earned: expected.earned,
            bonus: expected.bonus,
            buildings: [
              if (expected.buildings.isNotEmpty) expected.buildings,
              bought.key,
            ].join(' '),
          );
        } else {
          final event = step.event!;
          ledger = rules
              .gainsOf(ledger, event)
              .fold(ledger, (l, e) => l.apply(e));
          final (gained, bonus) = _reference(event);
          expected = (
            balance: expected.balance + gained,
            earned: expected.earned + gained,
            bonus: expected.bonus + bonus,
            buildings: expected.buildings,
          );
        }
        expect(_of(ledger), expected, reason: 'seed $seed, step $steps');
      }
    }
    expect(steps, 600 * 80);
  });
}
