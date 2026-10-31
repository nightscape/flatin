import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/distractor_strategy.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/gen_settings.dart';

void main() {
  test('drawn switches lie in their universes and reach none and all off', () {
    const types = {
      'nouns': {'a', 'o', 'kons'},
      'verbs': {'e', 'i'},
    };
    const forms = {
      'nouns': {'nom_sg', 'gen_sg'},
    };
    const features = {
      'verbs': {
        'genus_verbi': {'act', 'pass'},
      },
    };
    final rng = Random(352);
    var none = 0, all = 0;
    for (var i = 0; i < 500; i++) {
      final off = [0.0, 0.5, 1.0][i % 3];
      final s = drawSettings(
        rng,
        types: types,
        forms: forms,
        features: features,
        off: off,
      );
      final drawn = [
        for (final MapEntry(:key, :value) in s.disabledTypes.entries)
          for (final t in value) (types[key]!.contains(t), t),
        for (final MapEntry(:key, :value) in s.disabledForms.entries)
          for (final f in value) (forms[key]!.contains(f), f),
        for (final MapEntry(:key, :value) in s.disabledFeatures.entries)
          for (final MapEntry(key: axis, value: codes) in value.entries)
            for (final c in codes) (features[key]![axis]!.contains(c), c),
      ];
      expect(drawn.every((d) => d.$1), isTrue, reason: '$drawn');
      if (drawn.isEmpty) none++;
      if (drawn.length == 3 + 2 + 2 + 2) all++;
      expect(s.kursstand, inInclusiveRange(1, lastLesson));
      if (off == 0) expect(drawn, isEmpty);
      if (off == 1) expect(drawn.length, 9);
    }
    expect(none, greaterThan(0));
    expect(all, greaterThan(0));
  });

  test('without universes no switch is drawn', () {
    final rng = Random(353);
    for (var i = 0; i < 200; i++) {
      final s = drawSettings(rng);
      expect(s.disabledTypes, isEmpty);
      expect(s.disabledForms, isEmpty);
      expect(s.disabledFeatures, isEmpty);
      expect(s.forcedOnTypes, isEmpty);
      expect(s.forcedOnForms, isEmpty);
      expect(s.deselectedWords, isEmpty);
      expect(s.forcedOnWords, isEmpty);
      expect(s.deselectedTopics, isEmpty);
      expect(s.forcedOnTopics, isEmpty);
      expect(s.inputStrategyIds, isEmpty);
    }
  });

  test('every other field lies in its range and reaches a value other than '
      'its default', () {
    const types = {
      'nouns': {'a', 'o'},
    };
    const forms = {
      'verbs': {'inf', 'imp'},
    };
    const words = {'hīc', 'hic', 'porta'};
    const topics = {'1/nouns/a', '2/verbs/inf'};
    final fresh = Settings();
    final rng = Random(354);
    final reach = <String, int>{};
    void count(String what, bool hit) => reach.update(
      what,
      (n) => n + (hit ? 1 : 0),
      ifAbsent: () => hit ? 1 : 0,
    );
    for (var i = 0; i < 500; i++) {
      final s = drawSettings(
        rng,
        types: types,
        forms: forms,
        words: words,
        topics: topics,
      );
      expect(words, containsAll({...s.deselectedWords, ...s.forcedOnWords}));
      expect(topics, containsAll({...s.deselectedTopics, ...s.forcedOnTopics}));
      expect(switchableRewardIds, containsAll(s.disabledRewards));
      expect(s.inputStrategyIds.keys, everyElement(isIn({'nouns', 'verbs'})));
      expect(
        distractorStrategies.map((d) => d.id),
        contains(s.distractorStrategyId),
      );
      count('deselected words', s.deselectedWords.isNotEmpty);
      count('forced-on words', s.forcedOnWords.isNotEmpty);
      count('deselected topics', s.deselectedTopics.isNotEmpty);
      count('forced-on topics', s.forcedOnTopics.isNotEmpty);
      count('forced-on types', s.forcedOnTypes.values.any((t) => t.isNotEmpty));
      count('forced-on forms', s.forcedOnForms.values.any((f) => f.isNotEmpty));
      for (final id in switchableRewardIds) {
        count('$id off', !s.isRewardEnabled(id));
      }
      count(
        'every reward off',
        s.disabledRewards.length == switchableRewardIds.length,
      );
      count(
        'an input strategy other than the default',
        s.inputStrategyIds.values.any(
          (id) => id != fresh.getInputStrategyId('nouns'),
        ),
      );
      count('no reward animation', s.rewardAnimation != fresh.rewardAnimation);
      count('macron twins kept', s.avoidMacronTwins != fresh.avoidMacronTwins);
    }
    for (final MapEntry(:key, :value) in reach.entries) {
      expect(value, greaterThan(0), reason: 'never drawn: $key');
    }
  });
}
