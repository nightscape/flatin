import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _rules = GameRules.parse(
  File(gameRulesAsset).readAsStringSync(),
  gameRulesAsset,
);

RewardLedger _send(RewardLedger ledger, RewardEvent event) => [
  ..._rules.gainsOf(ledger, event),
  ...countDay(ledger, event),
].fold(ledger, (l, e) => l.apply(e));

Answered _answered({
  required bool right,
  required bool firstAttempt,
  required double? wordDifficulty,
  required DateTime at,
}) => Answered(
  right: right,
  firstAttempt: firstAttempt,
  wordDifficulty: wordDifficulty,
  kind: 'deLatWahl',
  dataFile: 'latin_nouns',
  at: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('random event sequences only grow the ledger and follow the rules', () {
    final random = Random(229);
    for (var run = 0; run < 200; run++) {
      var ledger = const RewardLedger();
      var at = DateTime(2026, 1, 1, 8);
      final days = <String>{};
      for (var i = 0; i < 100; i++) {
        final RewardEvent event;
        if (random.nextInt(8) == 0) {
          event = const RoundFinished();
        } else {
          at = at.add(Duration(hours: random.nextInt(30)));
          event = _answered(
            right: random.nextBool(),
            firstAttempt: random.nextBool(),
            wordDifficulty: random.nextBool() ? null : random.nextDouble() * 10,
            at: at,
          );
          days.add('${at.year}-${at.month}-${at.day}');
        }
        final next = _send(ledger, event);
        expect(
          next.earnedOf(coins),
          greaterThanOrEqualTo(ledger.earnedOf(coins)),
        );
        expect(next.buildings, ledger.buildings);
        expect(next.spent, isEmpty);
        expect(next.practiceDays, greaterThanOrEqualTo(ledger.practiceDays));
        if (event case Answered(
          :final right,
          :final firstAttempt,
          :final wordDifficulty,
        )) {
          final hard = wordDifficulty != null && wordDifficulty >= 7;
          expect(
            next.earnedOf(coins) - ledger.earnedOf(coins),
            right ? (firstAttempt ? 10 : 5) * (hard ? 2 : 1) : 0,
          );
          expect(
            next.taggedOf(coins, 'bonus') - ledger.taggedOf(coins, 'bonus'),
            right && hard ? (firstAttempt ? 10 : 5) : 0,
          );
        }
        ledger = next;
      }
      expect(ledger.practiceDays, days.length);
    }
  });

  test('buying spends the price, adds the building and cannot overdraw', () {
    const ledger = RewardLedger(earned: {coins: 900});
    final hortus = _rules.buildings.singleWhere((b) => b.id == 'hortus');
    final bought = _rules.buy(hortus).fold(ledger, (l, e) => l.apply(e));
    expect(bought.balance(coins), 650);
    expect(bought.earnedOf(coins), 900);
    expect(bought.buildings, ['hortus']);
    expect(
      () => bought.apply(const ResourceSpent(coins, 651)),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a check with k right choices adds 3k plain coins and nothing else', () {
    const ledger = RewardLedger(
      earned: {coins: 20},
      lastPracticeDay: '2026-01-01',
    );
    final next = _send(ledger, const ChoicesChecked(4));
    expect(next.earnedOf(coins), 32);
    expect(next.tagged, isEmpty);
    expect(next.practiceDays, 0);
    expect(() => ChoicesChecked(0), throwsA(isA<AssertionError>()));
  });

  group('the Argentaria', () {
    Answered right(double? difficulty) => _answered(
      right: true,
      firstAttempt: true,
      wordDifficulty: difficulty,
      at: DateTime(2026, 10, 26),
    );
    int gained(RewardLedger ledger, RewardEvent event) =>
        _send(ledger, event).earnedOf(coins) - ledger.earnedOf(coins);
    int bonus(RewardLedger ledger, RewardEvent event) =>
        _send(ledger, event).taggedOf(coins, 'bonus') -
        ledger.taggedOf(coins, 'bonus');
    const before = RewardLedger(earned: {coins: 1000}, buildings: ['domus']);
    final after = _rules
        .buy(_rules.buildings.singleWhere((b) => b.id == 'argentaria'))
        .fold(before, (l, e) => l.apply(e));

    test('costs 1000 coins and multiplies coins by 2 by its rule', () {
      expect(after.balance(coins), 0);
      expect(after.earnedOf(coins), before.earnedOf(coins));
      expect(_rules.multiplierOf(before, coins), 1);
      expect(_rules.multiplierOf(after, coins), 2);
    });

    test('leaves the gains before the purchase unchanged', () {
      expect(gained(before, right(null)), 10);
      expect(gained(before, right(9)), 20);
      expect(bonus(before, right(9)), 10);
      expect(gained(before, const ChoicesChecked(4)), 12);
    });

    test('doubles answered, bonus and choicesChecked gains', () {
      expect(gained(after, right(null)), 20);
      expect(gained(after, right(9)), 40);
      expect(bonus(after, right(9)), 20);
      expect(gained(after, const ChoicesChecked(4)), 24);
    });

    test('counts only when the loaded ledger lists it', () {
      RewardLedger load(List<String> buildings) => RewardLedger.fromJson(
        jsonDecode(
              jsonEncode({
                'earned': {coins: 1200},
                'tagged': {},
                'spent': {coins: 1000},
                'buildings': buildings,
                'practiceDays': 3,
                'lastPracticeDay': '2026-10-25',
              }),
            )
            as Map<String, Object?>,
      );
      expect(gained(load(['domus']), right(null)), 10);
      expect(gained(load(['domus', 'argentaria']), right(null)), 20);
    });
  });

  group('the Moneta', () {
    final right = _answered(
      right: true,
      firstAttempt: true,
      wordDifficulty: null,
      at: DateTime(2026, 10, 29),
    );
    const before = RewardLedger(earned: {coins: 11000});
    RewardLedger buy(RewardLedger ledger, String id) => _rules
        .buy(_rules.buildings.singleWhere((b) => b.id == id))
        .fold(ledger, (l, e) => l.apply(e));
    int gained(RewardLedger ledger) =>
        _send(ledger, right).earnedOf(coins) - ledger.earnedOf(coins);

    test('alone multiplies coins by 5', () {
      final after = buy(before, 'moneta');
      expect(_rules.multiplierOf(after, coins), 5);
      expect(gained(after), 50);
    });

    test('with the Argentaria multiplies coins by 10', () {
      final after = buy(buy(before, 'argentaria'), 'moneta');
      expect(after.balance(coins), 0);
      expect(_rules.multiplierOf(after, coins), 10);
      expect(gained(after), 100);
    });
  });

  test('the shop offers the unbuilt buildings, each with a price', () {
    expect(_rules.unbuilt(const RewardLedger()), _rules.buildings);
    expect(
      _rules.unbuilt(const RewardLedger(buildings: ['domus'])).first.id,
      'hortus',
    );
    expect(_rules.buildings.map((b) => b.price[coins]).toSet(), {
      250,
      400,
      600,
      1000,
      10000,
    });
  });

  test('a ledger with repeated ids offers the first step not built yet', () {
    const ledger = RewardLedger(buildings: ['domus', 'hortus', 'domus']);
    expect(_rules.unbuilt(ledger).first.id, 'fons');
  });

  test('a non-positive point gain is rejected', () {
    expect(
      () => const RewardLedger().apply(const ResourceGained(coins, 0)),
      throwsA(isA<AssertionError>()),
    );
  });

  test('ledger JSON round trip', () {
    var ledger = const RewardLedger();
    ledger = _send(
      ledger,
      _answered(
        right: true,
        firstAttempt: true,
        wordDifficulty: null,
        at: DateTime(2026, 3, 4),
      ),
    );
    ledger = ledger
        .apply(const ResourceGained(coins, 4, tag: 'bonus'))
        .apply(const ResourceSpent(coins, 5))
        .apply(const BuildingAdded('domus'));
    final back = RewardLedger.fromJson(
      jsonDecode(jsonEncode(ledger.toJson())) as Map<String, Object?>,
    );
    expect(back.toJson(), ledger.toJson());
    expect(back.earnedOf(coins), 14);
    expect(back.taggedOf(coins, 'bonus'), 4);
    expect(back.balance(coins), 9);
    expect(back.buildings, ['domus']);
    expect(back.lastPracticeDay, '2026-03-04');
  });

  test(
    'storage round trip; missing key is empty; parse error throws',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect((await RewardStorage.load()).earned, isEmpty);
      await RewardStorage.save(
        const RewardLedger(earned: {coins: 15}, buildings: ['domus']),
      );
      expect((await RewardStorage.load()).balance(coins), 15);

      SharedPreferences.setMockInitialValues({'rewards': '{not json'});
      await expectLater(RewardStorage.load(), throwsA(isA<FormatException>()));
    },
  );

  test('storage load rejects a stored version it does not know', () async {
    SharedPreferences.setMockInitialValues({
      'rewards': '{"version": 5, "earned": {}}',
    });
    await expectLater(RewardStorage.load(), throwsA(isA<AssertionError>()));
  });

  test('an earlier date after a later one counts its day again', () {
    var ledger = const RewardLedger();
    for (final day in [5, 4, 5]) {
      ledger = _send(
        ledger,
        _answered(
          right: false,
          firstAttempt: true,
          wordDifficulty: 9,
          at: DateTime(2026, 3, day),
        ),
      );
    }
    expect(ledger.practiceDays, 3);
    expect(ledger.earned, isEmpty);
  });

  test('the provider returns the effects and persists the ledger', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final effects = await container
        .read(rewardsProvider.notifier)
        .send(
          _answered(
            right: true,
            firstAttempt: false,
            wordDifficulty: null,
            at: DateTime(2026, 5, 6),
          ),
        );
    expect(effects.map((e) => e.runtimeType), [ResourceGained, DayCounted]);
    final stored = await RewardStorage.load();
    expect(stored.balance(coins), 5);
    expect(stored.practiceDays, 1);
  });
}
