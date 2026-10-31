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
  'argentaria': 1000,
  'moneta': 10000,
};

/// The town plan: each building with the buildings it requires.
const _requires = {
  'domus': <String>[],
  'hortus': <String>[],
  'fons': <String>[],
  'taberna': ['domus'],
  'villa': ['domus', 'hortus'],
  'templum': ['domus', 'fons'],
  'ager': <String>[],
  'vinea': ['ager'],
  'stabulum': ['ager'],
  'figlina': ['taberna', 'fons'],
  'pistrinum': ['ager', 'taberna'],
  'aquaeductus': ['fons', 'figlina'],
  'thermae': ['aquaeductus'],
  'statua': ['templum'],
  'portus': ['taberna', 'figlina'],
  'navis': ['portus'],
  'murus': ['figlina', 'stabulum'],
  'castra': ['murus', 'stabulum'],
  'bibliotheca': ['templum', 'villa'],
  'amphitheatrum': ['thermae', 'castra'],
  'argentaria': ['portus', 'bibliotheca', 'murus'],
  'moneta': ['argentaria', 'amphitheatrum'],
};

/// The bank doubles and the mint quintuples every coin gained while it stands.
int _times(String buildings) {
  final built = buildings.split(' ');
  return (built.contains('argentaria') ? 2 : 1) *
      (built.contains('moneta') ? 5 : 1);
}

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
    for (var i = 0; i < 120; i++)
      switch (random.nextInt(10)) {
        0 => (event: const RoundFinished(), buy: null),
        1 || 2 => (event: ChoicesChecked(1 + random.nextInt(20)), buy: null),
        3 || 4 || 5 => (event: null, buy: random.nextInt(20)),
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

  test('the rule file lists the requirements of the town plan', () {
    expect({for (final b in rules.buildings) b.id: b.requires}, _requires);
  });

  test('every building can be reached from the empty town', () {
    final built = <String>{};
    var progress = true;
    while (progress) {
      final next = [
        for (final e in _requires.entries)
          if (!built.contains(e.key) && built.containsAll(e.value)) e.key,
      ];
      progress = next.isNotEmpty;
      built.addAll(next);
    }
    expect(built, _prices.keys.toSet());
  });

  test('the rule file and the reference agree after every event', () {
    var steps = 0;
    final richStart = rules.buildings.fold(0, (s, b) => s + b.price[coins]!);
    final bought = <String>{};
    final multipliers = <int>{};
    for (var seed = 0; seed < 600; seed++) {
      // Odd seeds start rich enough to buy every building.
      final start = seed.isOdd ? richStart : 0;
      var ledger = RewardLedger(earned: {coins: start});
      var expected = (balance: start, earned: start, bonus: 0, buildings: '');
      for (final step in _sequence(Random(seed))) {
        steps++;
        if (step.buy case final pick?) {
          final built = expected.buildings.split(' ');
          final offer = [
            for (final e in _prices.entries)
              if (!built.contains(e.key) &&
                  e.value <= expected.balance &&
                  built.toSet().containsAll(_requires[e.key]!))
                e,
          ];
          if (offer.isEmpty) continue;
          final choice = offer[pick % offer.length];
          bought.add(choice.key);
          ledger = rules
              .buy(
                ledger,
                rules.buildings.singleWhere((b) => b.id == choice.key),
              )
              .fold(ledger, (l, e) => l.apply(e));
          expected = (
            balance: expected.balance - choice.value,
            earned: expected.earned,
            bonus: expected.bonus,
            buildings: [
              if (expected.buildings.isNotEmpty) expected.buildings,
              choice.key,
            ].join(' '),
          );
        } else {
          final event = step.event!;
          ledger = rules
              .gainsOf(ledger, event)
              .fold(ledger, (l, e) => l.apply(e));
          final (gained, bonus) = _reference(event);
          final times = _times(expected.buildings);
          if (gained > 0) multipliers.add(times);
          expected = (
            balance: expected.balance + gained * times,
            earned: expected.earned + gained * times,
            bonus: expected.bonus + bonus * times,
            buildings: expected.buildings,
          );
        }
        expect(_of(ledger), expected, reason: 'seed $seed, step $steps');
      }
    }
    expect(steps, 600 * 120);
    expect(bought, {for (final b in rules.buildings) b.id});
    expect(multipliers, {1, 2, 10});
  });
}
