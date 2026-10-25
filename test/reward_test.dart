import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_keys.dart';

RewardLedger _send(RewardLedger ledger, RewardEvent event) => [
  for (final s in rewardStrategies) ...s.onEvent(event, ledger),
].fold(ledger, (l, e) => l.apply(e));

void main() {
  test('random event sequences only grow the ledger and follow the rules', () {
    final random = Random(229);
    for (var run = 0; run < 200; run++) {
      var ledger = const RewardLedger();
      var at = DateTime(2026, 1, 1, 8);
      final days = <String>{};
      var rounds = 0;
      for (var i = 0; i < 100; i++) {
        final RewardEvent event;
        if (random.nextInt(8) == 0) {
          event = const RoundFinished();
          rounds++;
        } else {
          at = at.add(Duration(hours: random.nextInt(30)));
          event = Answered(
            right: random.nextBool(),
            firstAttempt: random.nextBool(),
            wordDifficulty: random.nextBool() ? null : random.nextDouble() * 10,
            at: at,
          );
          days.add('${at.year}-${at.month}-${at.day}');
        }
        final next = _send(ledger, event);
        expect(next.points, greaterThanOrEqualTo(ledger.points));
        expect(
          next.buildings.length,
          ledger.buildings.length +
              (event is RoundFinished &&
                      ledger.buildings.length < romanTown.length
                  ? 1
                  : 0),
        );
        expect(next.practiceDays, greaterThanOrEqualTo(ledger.practiceDays));
        if (event case Answered(
          :final right,
          :final firstAttempt,
          :final wordDifficulty,
        )) {
          final hard = wordDifficulty != null && wordDifficulty >= 7;
          expect(
            next.points - ledger.points,
            right ? (firstAttempt ? 10 : 5) * (hard ? 2 : 1) : 0,
          );
          expect(
            next.bonusPoints - ledger.bonusPoints,
            right && hard ? (firstAttempt ? 10 : 5) : 0,
          );
        }
        ledger = next;
      }
      expect(ledger.buildings.length, min(rounds, romanTown.length));
      expect(ledger.practiceDays, days.length);
      expect(ledger.buildings.first, romanTown.first.id);
    }
  });

  test(
    'the town is complete after the last building and adds nothing more',
    () {
      var ledger = const RewardLedger();
      for (var i = 0; i < romanTown.length; i++) {
        ledger = _send(ledger, const RoundFinished());
      }
      expect(ledger.buildings, romanTown.map((b) => b.id));
      expect(nextBuilding(ledger), isNull);
      expect(_send(ledger, const RoundFinished()).buildings, ledger.buildings);
    },
  );

  test('a ledger with repeated ids builds the first step not built yet', () {
    const ledger = RewardLedger(buildings: ['domus', 'hortus', 'domus']);
    expect(townOf(ledger).map((b) => b.id), ['domus', 'hortus']);
    expect(nextBuilding(ledger)!.id, 'fons');
  });

  test('a non-positive point gain is rejected', () {
    expect(
      () => const RewardLedger().apply(const PointsGained(0)),
      throwsA(isA<AssertionError>()),
    );
  });

  test('ledger JSON round trip', () {
    var ledger = const RewardLedger();
    ledger = _send(
      ledger,
      Answered(
        right: true,
        firstAttempt: true,
        wordDifficulty: null,
        at: DateTime(2026, 3, 4),
      ),
    );
    ledger = _send(ledger, const RoundFinished());
    final back = RewardLedger.fromJson(ledger.toJson());
    expect(back.toJson(), ledger.toJson());
    expect(back.points, 10);
    expect(back.buildings, ['domus']);
    expect(back.lastPracticeDay, '2026-03-04');
  });

  test(
    'storage round trip; missing key is empty; parse error throws',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect((await RewardStorage.load()).points, 0);
      await RewardStorage.save(
        const RewardLedger(points: 15, buildings: ['domus']),
      );
      expect((await RewardStorage.load()).points, 15);

      SharedPreferences.setMockInitialValues({'rewards': '{not json'});
      await expectLater(RewardStorage.load(), throwsA(isA<FormatException>()));
    },
  );

  test('a version-1 ledger loads with no bonus points', () async {
    SharedPreferences.setMockInitialValues({
      'rewards':
          '{"version": 1, "points": 15, "buildings": ["domus"], '
          '"practiceDays": 2, "lastPracticeDay": "2026-03-04"}',
    });
    final ledger = await RewardStorage.load();
    expect(ledger.points, 15);
    expect(ledger.bonusPoints, 0);
    expect(ledger.buildings, ['domus']);
    expect(ledger.practiceDays, 2);
  });

  test('the bonus is the base points again from difficulty 7', () {
    Set<int> bonusFor(bool right, bool first, double? difficulty) => {
      for (final e in const HardWordBonusStrategy().onEvent(
        Answered(
          right: right,
          firstAttempt: first,
          wordDifficulty: difficulty,
          at: DateTime(2026, 3, 4),
        ),
        const RewardLedger(),
      ))
        (e as BonusGained).points,
    };
    expect(bonusFor(true, true, 7), {10});
    expect(bonusFor(true, true, 10), {10});
    expect(bonusFor(true, true, 6.99), isEmpty);
    expect(bonusFor(true, true, null), isEmpty);
    expect(bonusFor(true, false, 8), {5});
    expect(bonusFor(false, true, 9), isEmpty);
  });

  test('storage load rejects a stored version it does not know', () async {
    SharedPreferences.setMockInitialValues({
      'rewards': '{"version": 3, "points": 5}',
    });
    await expectLater(RewardStorage.load(), throwsA(isA<AssertionError>()));
  });

  test('an earlier date after a later one counts its day again', () {
    var ledger = const RewardLedger();
    for (final day in [5, 4, 5]) {
      ledger = _send(
        ledger,
        Answered(
          right: false,
          firstAttempt: true,
          wordDifficulty: 9,
          at: DateTime(2026, 3, day),
        ),
      );
    }
    expect(ledger.practiceDays, 3);
    expect(ledger.points, 0);
  });

  test('every building has a unique id, an image and a name in de and en', () {
    expect(romanTown, hasLength(20));
    expect(romanTown.map((b) => b.id).toSet(), hasLength(romanTown.length));
    for (final b in romanTown) {
      expect(
        File('assets/town/${b.id}.png').existsSync(),
        isTrue,
        reason: b.id,
      );
    }
    for (final code in ['de', 'en']) {
      final keys = translationKeys(code);
      for (final b in romanTown) {
        expect(keys, contains('reward.building.${b.id}'));
      }
    }
  });

  test('the provider returns the effects and persists the ledger', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final effects = await container
        .read(rewardsProvider.notifier)
        .send(
          Answered(
            right: true,
            firstAttempt: false,
            wordDifficulty: null,
            at: DateTime(2026, 5, 6),
          ),
        );
    expect(effects.map((e) => e.runtimeType), [PointsGained, DayCounted]);
    final stored = await RewardStorage.load();
    expect(stored.points, 5);
    expect(stored.practiceDays, 1);
  });
}
