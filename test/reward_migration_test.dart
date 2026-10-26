import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<RewardLedger> _load(String fixture) {
  SharedPreferences.setMockInitialValues({
    'rewards': File('test/fixtures/rewards/$fixture.json').readAsStringSync(),
  });
  return RewardStorage.load();
}

typedef _Expected = ({
  int balance,
  int earned,
  int bonus,
  List<String> buildings,
  int practiceDays,
  String? lastPracticeDay,
});

void main() {
  final cases = <String, _Expected>{
    'v3_town': (
      balance: 495,
      earned: 1745,
      bonus: 130,
      buildings: ['domus', 'hortus', 'fons', 'taberna'],
      practiceDays: 9,
      lastPracticeDay: '2026-10-24',
    ),
    'v3_empty': (
      balance: 0,
      earned: 0,
      bonus: 0,
      buildings: [],
      practiceDays: 0,
      lastPracticeDay: null,
    ),
    'v3_repeated': (
      balance: 255,
      earned: 905,
      bonus: 0,
      buildings: ['templum', 'domus', 'templum'],
      practiceDays: 3,
      lastPracticeDay: '2026-09-30',
    ),
    // Versions 1 and 2 predate the shop: their buildings are dropped.
    'v2': (
      balance: 240,
      earned: 240,
      bonus: 20,
      buildings: [],
      practiceDays: 4,
      lastPracticeDay: '2026-03-04',
    ),
    'v1': (
      balance: 15,
      earned: 15,
      bonus: 0,
      buildings: [],
      practiceDays: 2,
      lastPracticeDay: '2026-03-04',
    ),
  };
  for (final MapEntry(key: fixture, value: expected) in cases.entries) {
    test('the stored $fixture ledger loads with the same balance', () async {
      final ledger = await _load(fixture);
      expect(ledger.balance(coins), expected.balance);
      expect(ledger.earnedOf(coins), expected.earned);
      expect(ledger.taggedOf(coins, 'bonus'), expected.bonus);
      expect(ledger.buildings, expected.buildings);
      expect(ledger.practiceDays, expected.practiceDays);
      expect(ledger.lastPracticeDay, expected.lastPracticeDay);

      await RewardStorage.save(ledger);
      expect(
        (await RewardStorage.load()).toJson(),
        ledger.toJson(),
        reason: 'the migrated ledger saves in the new format',
      );
    });
  }
}
