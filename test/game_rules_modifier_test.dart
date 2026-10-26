import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/models/reward.dart';

GameRules _rules(String modifier) => GameRules.parse('''
resources: [coins]
earn:
  - on: answered
    when: {right: true}
    gain: {coins: 10}
  - on: answered
    when: {right: true, wordDifficultyAtLeast: 7}
    gain: {coins: 10}
    tag: bonus
buildings:
  - {id: argentaria, price: {coins: 1}, modifies: [{resource: coins, $modifier}]}
''', 'rules.yaml');

List<ResourceGained> _gains(GameRules rules, double difficulty) =>
    rules.gainsOf(
      const RewardLedger(buildings: ['argentaria']),
      Answered(
        right: true,
        firstAttempt: true,
        wordDifficulty: difficulty,
        kind: 'k',
        dataFile: 'f',
        at: DateTime(2026),
      ),
    );

int _gain(GameRules rules, double difficulty) =>
    _gains(rules, difficulty).fold(0, (s, e) => s + e.amount);

void main() {
  test('an add modifier adds once to the per-resource sum', () {
    // sum per resource: 10 + 10 = 20, then add 2 -> 22
    expect(_gain(_rules('add: 2'), 8), 22);
  });
  test('a multiply modifier rounds the per-resource sum once', () {
    // 20 * 1.05 = 21
    expect(_gain(_rules('multiply: 1.05'), 8), 21);
  });
  test('the bonus share is its gains times the multiplies, rounded', () {
    List<(int, String?)> shares(String modifier) => [
      for (final g in _gains(_rules(modifier), 8)) (g.amount, g.tag),
    ];
    expect(shares('add: 2'), [(12, null), (10, 'bonus')]);
    expect(shares('multiply: 1.05'), [(10, null), (11, 'bonus')]);
  });
}
