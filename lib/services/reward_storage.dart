import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reward.dart';

class RewardStorage {
  static const String _storageKey = 'rewards';
  static const int _currentVersion = 2;

  /// Version 1 has no bonus points; they load as 0.

  /// A missing key is an empty ledger. A parse error throws: a silent reset
  /// would erase what the learner earned.
  static Future<RewardLedger> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return const RewardLedger();
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    assert(
      json['version'] == _currentVersion || json['version'] == 1,
      'rewards version: $json',
    );
    return RewardLedger.fromJson(json);
  }

  static Future<void> save(RewardLedger ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({'version': _currentVersion, ...ledger.toJson()}),
    );
  }
}
