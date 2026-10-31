import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/reward.dart';

import 'support/i18n_keys.dart';

const _file = 'rules.yaml';

String _rules({String earn = '', String buildings = ''}) =>
    'resources: [coins]\n'
    'earn:${earn.isEmpty ? ' []' : '\n$earn'}\n'
    'buildings:${buildings.isEmpty ? ' []' : '\n$buildings'}\n';

Matcher _failsAt(String path) => throwsA(
  isA<FormatException>().having(
    (e) => e.message,
    'message',
    startsWith('$_file: $path: '),
  ),
);

Answered _answered({bool right = true, double? difficulty}) => Answered(
  right: right,
  firstAttempt: true,
  wordDifficulty: difficulty,
  kind: 'deLatWahl',
  dataFile: 'latin_nouns',
  at: DateTime(2026, 3, 4),
);

void main() {
  group('loading fails naming the file and the path', () {
    test('of an unknown key', () {
      expect(
        () => GameRules.parse(
          _rules(earn: '  - {on: answered, gain: {coins: 1}, gian: 2}'),
          _file,
        ),
        _failsAt('earn[0].gian'),
      );
    });

    test('of an unknown event', () {
      expect(
        () => GameRules.parse(
          _rules(earn: '  - {on: answer, gain: {coins: 1}}'),
          _file,
        ),
        _failsAt('earn[0].on'),
      );
    });

    test('of an unknown resource', () {
      expect(
        () => GameRules.parse(
          _rules(buildings: '  - {id: domus, price: {coins: 1, stone: 2}}'),
          _file,
        ),
        _failsAt('buildings[0].price.stone'),
      );
    });

    test('of an unknown required building', () {
      expect(
        () => GameRules.parse(
          _rules(
            buildings:
                '  - {id: domus, price: {coins: 1}}\n'
                '  - {id: villa, price: {coins: 1}, requires: [domus, hortus]}',
          ),
          _file,
        ),
        _failsAt('buildings[1].requires[1]'),
      );
    });

    test('of a cycle between buildings, naming the ids', () {
      expect(
        () => GameRules.parse(
          _rules(
            buildings:
                '  - {id: a, price: {coins: 1}, requires: [b]}\n'
                '  - {id: b, price: {coins: 1}, requires: [a]}\n'
                '  - {id: c, price: {coins: 1}}',
          ),
          _file,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('cycle'), contains('a'), contains('b')),
          ),
        ),
      );
    });

    test('of a building that requires itself', () {
      expect(
        () => GameRules.parse(
          _rules(buildings: '  - {id: a, price: {coins: 1}, requires: [a]}'),
          _file,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('of a when field the event does not have', () {
      expect(
        () => GameRules.parse(
          _rules(
            earn:
                '  - {on: choicesChecked, when: {firstAttempt: true}, '
                'gain: {coins: 1}}',
          ),
          _file,
        ),
        _failsAt('earn[0].when.firstAttempt'),
      );
    });

    test('of a second tag for one resource', () {
      expect(
        () => GameRules.parse(
          _rules(
            earn:
                '  - {on: answered, gain: {coins: 1}, tag: bonus}\n'
                '  - {on: answered, gain: {coins: 1}, tag: streak}',
          ),
          _file,
        ),
        _failsAt('earn[1].tag'),
      );
    });

    test('of a per field the event does not count', () {
      expect(
        () => GameRules.parse(
          _rules(earn: '  - {on: answered, per: right, gain: {coins: 1}}'),
          _file,
        ),
        _failsAt('earn[0].per'),
      );
    });
  });

  test('buying a building with missing prerequisites throws', () {
    final rules = GameRules.parse(
      _rules(
        buildings:
            '  - {id: a, price: {coins: 1}}\n'
            '  - {id: c, price: {coins: 1}, requires: [a]}',
      ),
      _file,
    );
    const ledger = RewardLedger(earned: {coins: 5});
    expect(
      () => rules.buy(ledger, rules.buildings.last),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'c needs a'),
      ),
    );
    expect(
      rules.buy(const RewardLedger(buildings: ['a']), rules.buildings.last),
      isNotEmpty,
    );
  });

  test('missingFor lists the prerequisites not built, in file order', () {
    final rules = GameRules.parse(
      _rules(
        buildings:
            '  - {id: a, price: {coins: 1}}\n'
            '  - {id: b, price: {coins: 1}}\n'
            '  - {id: c, price: {coins: 1}, requires: [b, a]}',
      ),
      _file,
    );
    final c = rules.buildings.last;
    expect(c.requires, ['b', 'a']);
    expect(rules.missingFor(const RewardLedger(), c), ['b', 'a']);
    expect(rules.missingFor(const RewardLedger(buildings: ['b']), c), ['a']);
    expect(rules.missingFor(const RewardLedger(buildings: ['a', 'b']), c), []);
    expect(rules.missingFor(const RewardLedger(), rules.buildings.first), []);
  });

  test('the facts of every event are the fields the loader knows', () {
    for (final event in [
      _answered(),
      const ChoicesChecked(1),
      const RoundFinished(),
    ]) {
      expect(event.facts.keys, rewardEventFields[rewardEventName(event)]!.keys);
    }
  });

  test('gains add up per resource; built modifiers add, then multiply, then '
      'round; a tag keeps its multiplied share', () {
    final rules = GameRules.parse(
      _rules(
        earn:
            '  - {on: answered, when: {right: true}, gain: {coins: 3}}\n'
            '  - {on: answered, when: {right: [true]}, gain: {coins: 4}}\n'
            '  - {on: answered, when: {wordDifficultyAtLeast: 7}, '
            'gain: {coins: 2}, tag: bonus}',
        buildings:
            '  - {id: a, price: {coins: 1}, modifies: '
            '[{resource: coins, multiply: 1.5}]}\n'
            '  - {id: b, price: {coins: 1}, modifies: '
            '[{resource: coins, add: 2}]}',
      ),
      _file,
    );
    List<(String, int, String?)> gains(List<String> built, Answered event) => [
      for (final g in rules.gainsOf(RewardLedger(buildings: built), event))
        (g.resource, g.amount, g.tag),
    ];
    expect(gains([], _answered(difficulty: 7)), [
      (coins, 7, null),
      (coins, 2, 'bonus'),
    ]);
    expect(gains([], _answered(difficulty: 6.9)), [(coins, 7, null)]);
    expect(gains([], _answered(right: false)), isEmpty);
    expect(gains(['a'], _answered()), [(coins, 11, null)]);
    expect(gains(['a', 'b'], _answered()), [(coins, 14, null)]);
    expect(gains(['b'], _answered(right: false, difficulty: 9)), [
      (coins, 2, null),
      (coins, 2, 'bonus'),
    ]);
    expect(gains(['a'], _answered(right: false, difficulty: 9)), [
      (coins, 3, 'bonus'),
    ]);
  });

  test('every building has a unique id, an image and a name in de and en', () {
    final rules = GameRules.parse(
      File(gameRulesAsset).readAsStringSync(),
      gameRulesAsset,
    );
    expect(rules.buildings, hasLength(22));
    for (final b in rules.buildings) {
      expect(
        File('assets/town/${b.id}.png').existsSync(),
        isTrue,
        reason: b.id,
      );
    }
    for (final code in ['de', 'en']) {
      final keys = translationKeys(code);
      for (final b in rules.buildings) {
        expect(keys, contains('reward.building.${b.id}'));
        if (b.modifies.isNotEmpty) {
          expect(keys, contains('reward.effect.${b.id}'));
        }
      }
    }
  });

  test('every building has a town slot and every slot a building', () {
    final rules = GameRules.parse(
      File(gameRulesAsset).readAsStringSync(),
      gameRulesAsset,
    );
    final ids = {for (final b in rules.buildings) b.id};
    final slotted = {for (final s in townSprites) s.building};
    expect(slotted.difference(ids), isEmpty, reason: 'slots without building');
    expect(ids.difference(slotted), isEmpty, reason: 'buildings without slot');
  });
}
