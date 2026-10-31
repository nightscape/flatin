import 'dart:math';

import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/distractor_strategy.dart';
import 'package:latin_practice/models/input_strategy.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

typedef Json = Map<String, dynamic>;

/// Settings the app can hold: any word and grammar range of 1..Später (open
/// at the top with chance [openEnd]), both grammar links, any set of switched
/// off rewards, both on/off toggles, and a Kursstand that is derived from the
/// ranges (chance [derived]), at a range end (chance [atRangeEnd]) or any
/// lesson.
///
/// The learner's overrides are drawn only from the universes given: each
/// type of [types], form of [forms], value of [features] (data file id ->
/// axis id -> codes), word of [words] and topic key of [topics] is off with
/// chance [off], so `off: 1` empties the pool; a type, form, word or topic
/// that is not off is forced on with chance [forced]. Each data file the
/// universes name gets any input strategy or none.
Settings drawSettings(
  Random rng, {
  double openEnd = 0.25,
  double derived = 0.25,
  double atRangeEnd = 0.5,
  Map<String, Set<String>> types = const {},
  Map<String, Set<String>> forms = const {},
  Map<String, Map<String, Set<String>>> features = const {},
  Set<String> words = const {},
  Set<String> topics = const {},
  double off = 0.5,
  double forced = 0.25,
}) {
  LessonRange range() {
    final from = 1 + rng.nextInt(laterLesson);
    final to = rng.nextDouble() < openEnd
        ? laterLesson
        : from + rng.nextInt(laterLesson - from + 1);
    return LessonRange(from, to);
  }

  (Set<String>, Set<String>) offAndOn(Set<String> all) {
    final (offSet, onSet) = (<String>{}, <String>{});
    for (final entry in all) {
      if (rng.nextDouble() < off) {
        offSet.add(entry);
      } else if (rng.nextDouble() < forced) {
        onSet.add(entry);
      }
    }
    return (offSet, onSet);
  }

  Set<String> someOf(Set<String> all) => {
    for (final entry in all)
      if (rng.nextDouble() < off) entry,
  };

  final wordRange = range();
  final grammarRange = range();
  final kursstand = rng.nextDouble();
  final typeOverrides = {
    for (final MapEntry(:key, :value) in types.entries) key: offAndOn(value),
  };
  final formOverrides = {
    for (final MapEntry(:key, :value) in forms.entries) key: offAndOn(value),
  };
  final (wordsOff, wordsOn) = offAndOn(words);
  final (topicsOff, topicsOn) = offAndOn(topics);
  final files = {...types.keys, ...forms.keys, ...features.keys};
  return Settings(
    courseWords: wordRange,
    courseGrammar: grammarRange,
    grammarFromLinked: rng.nextBool(),
    grammarToLinked: rng.nextBool(),
    disabledRewards: {
      for (final id in switchableRewardIds)
        if (rng.nextBool()) id,
    },
    kursstand: kursstand < derived
        ? null
        : kursstand < derived + atRangeEnd
        ? min((rng.nextBool() ? wordRange : grammarRange).to, lastLesson)
        : 1 + rng.nextInt(lastLesson),
    disabledTypes: {
      for (final MapEntry(:key, :value) in typeOverrides.entries) key: value.$1,
    },
    forcedOnTypes: {
      for (final MapEntry(:key, :value) in typeOverrides.entries) key: value.$2,
    },
    disabledForms: {
      for (final MapEntry(:key, :value) in formOverrides.entries) key: value.$1,
    },
    forcedOnForms: {
      for (final MapEntry(:key, :value) in formOverrides.entries) key: value.$2,
    },
    disabledFeatures: {
      for (final MapEntry(key: file, value: axes) in features.entries)
        file: {
          for (final MapEntry(:key, :value) in axes.entries) key: someOf(value),
        },
    },
    deselectedWords: wordsOff,
    forcedOnWords: wordsOn,
    deselectedTopics: topicsOff,
    forcedOnTopics: topicsOn,
    inputStrategyIds: {
      for (final file in files)
        if (rng.nextBool())
          file: InputStrategy.all[rng.nextInt(InputStrategy.all.length)].id,
    },
    distractorStrategyId:
        distractorStrategies[rng.nextInt(distractorStrategies.length)].id,
    rewardAnimation: rng.nextBool(),
    avoidMacronTwins: rng.nextBool(),
  );
}

/// The stored JSON of [drawSettings]; with chance [withoutKursstand] it holds
/// no Kursstand, so that `Settings.fromJson` derives it from the ranges.
Json drawStoredSettings(
  Random rng, {
  double withoutKursstand = 0.25,
  double openEnd = 0.25,
  double derived = 0.25,
  double atRangeEnd = 0.5,
  Map<String, Set<String>> types = const {},
  Map<String, Set<String>> forms = const {},
  Map<String, Map<String, Set<String>>> features = const {},
  Set<String> words = const {},
  Set<String> topics = const {},
  double off = 0.5,
  double forced = 0.25,
}) {
  final json = drawSettings(
    rng,
    openEnd: openEnd,
    derived: derived,
    atRangeEnd: atRangeEnd,
    types: types,
    forms: forms,
    features: features,
    words: words,
    topics: topics,
    off: off,
    forced: forced,
  ).toJson();
  if (rng.nextDouble() < withoutKursstand) json.remove('kursstand');
  return json;
}
