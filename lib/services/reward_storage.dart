import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reward.dart';

class RewardStorage {
  static const String _storageKey = 'rewards';
  static const int _currentVersion = 4;

  /// A missing key is an empty ledger. A parse error throws: a silent reset
  /// would erase what the learner earned.
  static Future<RewardLedger> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return const RewardLedger();
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final version = json['version'] as int;
    assert(version <= _currentVersion, 'rewards version: $json');
    return RewardLedger.fromJson(version < 4 ? _fromPoints(json) : json);
  }

  /// Versions 1 to 3 count coins as `points`, with the `bonusPoints` share,
  /// minus the `spent` coins. Versions 1 and 2 predate the shop: they load
  /// with an empty town, so the learner buys the buildings again.
  static Map<String, Object?> _fromPoints(Map<String, dynamic> json) {
    final bonus = json['bonusPoints'] as int? ?? 0;
    final spent = json['spent'] as int? ?? 0;
    return {
      'earned': {coins: json['points'] as int},
      'tagged': {
        if (bonus > 0) coins: {'bonus': bonus},
      },
      'spent': {if (spent > 0) coins: spent},
      'buildings': json['version'] as int < 3
          ? const <String>[]
          : json['buildings'],
      'practiceDays': json['practiceDays'],
      'lastPracticeDay': json['lastPracticeDay'],
    };
  }

  static Future<void> save(RewardLedger ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({'version': _currentVersion, ...ledger.toJson()}),
    );
  }
}
