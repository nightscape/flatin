import 'dart:math';

import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/distractor_strategy.dart';
import 'package:latin_practice/models/exam_units.dart';
import 'package:latin_practice/models/input_strategy.dart';
import 'package:latin_practice/models/lernziel_chips.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';

typedef Json = Map<String, dynamic>;

/// Settings the app can hold: any word and grammar range of 1..Später (open
/// at the top with chance [openEnd], 1..1 with chance [firstOnly], the full
/// range with chance [full]), both grammar links, any set of switched
/// off rewards, both on/off toggles, and a Kursstand that is derived from the
/// ranges (chance [derived]), at a range end (chance [atRangeEnd]) or any
/// lesson.
///
/// The learner's overrides are drawn only from the universes given: each
/// type of [types], form of [forms], value of [features] (data file id ->
/// axis id -> codes), word of [words] and topic key of [topics] is off with
/// chance [off], so `off: 1` empties the pool; [formsOff], [featuresOff],
/// [wordsOff] and [topicsOff] replace [off] for their universe. A type, form,
/// word or topic that is not off is forced on with chance [forced]. Each data
/// file the universes name gets any input strategy or none. With [exam], the
/// exam settings are drawn too: any translation unit, points on or off.
Settings drawSettings(
  Random rng, {
  double openEnd = 0.25,
  double derived = 0.25,
  double atRangeEnd = 0.5,
  double firstOnly = 0,
  double full = 0,
  Map<String, Set<String>> types = const {},
  Map<String, Set<String>> forms = const {},
  Map<String, Map<String, Set<String>>> features = const {},
  Set<String> words = const {},
  Set<String> topics = const {},
  double off = 0.5,
  double? formsOff,
  double? featuresOff,
  double? wordsOff,
  double? topicsOff,
  double forced = 0.25,
  bool exam = false,
}) {
  LessonRange range() {
    // Drawn only when asked for, so the other callers keep their draws.
    if (firstOnly + full > 0) {
      final u = rng.nextDouble();
      if (u < firstOnly) return LessonRange(1, 1);
      if (u < firstOnly + full) return LessonRange.full;
    }
    final from = 1 + rng.nextInt(laterLesson);
    final to = rng.nextDouble() < openEnd
        ? laterLesson
        : from + rng.nextInt(laterLesson - from + 1);
    return LessonRange(from, to);
  }

  (Set<String>, Set<String>) offAndOn(Set<String> all, double off) {
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

  Set<String> someOf(Set<String> all, double off) => {
    for (final entry in all)
      if (rng.nextDouble() < off) entry,
  };

  final wordRange = range();
  final grammarRange = range();
  final kursstand = rng.nextDouble();
  final typeOverrides = {
    for (final MapEntry(:key, :value) in types.entries)
      key: offAndOn(value, off),
  };
  final formOverrides = {
    for (final MapEntry(:key, :value) in forms.entries)
      key: offAndOn(value, formsOff ?? off),
  };
  final (wordOffs, wordOns) = offAndOn(words, wordsOff ?? off);
  final (topicOffs, topicOns) = offAndOn(topics, topicsOff ?? off);
  final files = {...types.keys, ...forms.keys, ...features.keys};
  final settings = Settings(
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
          for (final MapEntry(:key, :value) in axes.entries)
            key: someOf(value, featuresOff ?? off),
        },
    },
    deselectedWords: wordOffs,
    forcedOnWords: wordOns,
    deselectedTopics: topicOffs,
    forcedOnTopics: topicOns,
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
  // Drawn only when asked for, so the other callers keep their draws.
  if (!exam) return settings;
  return settings.copyWith(
    uebersetzungseinheit: Uebersetzungseinheit
        .values[rng.nextInt(Uebersetzungseinheit.values.length)],
    punkteAnzeige: rng.nextBool(),
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

/// [drawSettings] whose word and grammar ranges, each with chance [atPreset],
/// equal one of the Lernziel presets of its Kursstand on the volumes
/// starting at [bookStarts]; the link rule of [Settings] still applies.
Settings drawLernzielSettings(
  Random rng,
  List<int> bookStarts, {
  double atPreset = 0.5,
}) {
  final drawn = drawSettings(rng);
  final presets = chipsFor(drawn.kursstand, bookStarts);
  LessonRange pick(LessonRange range) => rng.nextDouble() < atPreset
      ? presets[rng.nextInt(presets.length)]
      : range;
  return drawn.copyWith(
    courseWords: pick(drawn.courseWords),
    courseGrammar: pick(drawn.courseGrammar),
  );
}

/// A book scale: its volume starts, expansions, left end, track width and
/// Kursstand.
typedef BookScaleCase = ({
  List<int> starts,
  List<double> expansion,
  double left,
  double width,
  int kursstand,
});

/// A course of 1 to 4 volumes with any starts, each volume closed, open, at
/// rest or anywhere between, on a track from just wider than the closed
/// books to 1400 px more, and any Kursstand.
BookScaleCase drawBookScaleCase(Random rng) {
  final starts = {
    1,
    for (var i = rng.nextInt(4); i > 0; i--) 2 + rng.nextInt(lastLesson - 1),
  }.toList()..sort();
  double weight() => switch (rng.nextInt(4)) {
    0 => 0.0,
    1 => 1.0,
    2 => 0.3,
    _ => rng.nextDouble(),
  };
  return (
    starts: starts,
    expansion: [for (final _ in starts) weight()],
    left: rng.nextDouble() * 30,
    width: (starts.length + 1) * 22 + 1 + rng.nextDouble() * 1400,
    kursstand: 1 + rng.nextInt(lastLesson),
  );
}

/// The override universes of [drawSettings] over the items of a course:
/// each data file's types, forms and axis values, every lemma, and the
/// course's topic keys.
typedef Universes = ({
  Map<String, Set<String>> types,
  Map<String, Set<String>> forms,
  Map<String, Map<String, Set<String>>> features,
  Set<String> words,
  Set<String> topics,
});

Universes universesOf(List<PracticeItem> items, Set<String> topics) {
  final features = <String, Map<String, Set<String>>>{};
  for (final item in items) {
    for (final label in item.formLabels) {
      for (final MapEntry(:key, :value) in label.features.entries) {
        features
            .putIfAbsent(item.dataFileId, () => {})
            .putIfAbsent(key, () => {})
            .add(value);
      }
    }
  }
  Map<String, Set<String>> byFile(Iterable<String> Function(PracticeItem) of) {
    final byFile = <String, Set<String>>{};
    for (final item in items) {
      byFile.putIfAbsent(item.dataFileId, () => {}).addAll(of(item));
    }
    return byFile;
  }

  return (
    types: byFile((item) => [item.type]),
    forms: byFile((item) => item.formOrder),
    features: features,
    words: {for (final item in items) item.lemma},
    topics: topics,
  );
}

/// [u] with one more word, topic, and type, form and axis value per data
/// file that the course does not have, as in settings saved before they were
/// renamed or removed.
Universes withOrphans(Universes u) {
  Map<String, Set<String>> plus(Map<String, Set<String>> m, String entry) => {
    for (final MapEntry(:key, :value) in m.entries) key: {...value, entry},
  };
  return (
    types: plus(u.types, 'Orphan-Typ'),
    forms: plus(u.forms, 'orphan.key'),
    features: {
      for (final MapEntry(key: file, value: axes) in u.features.entries)
        file: plus(axes, 'orphan'),
    },
    words: {...u.words, 'orphanwort'},
    topics: {...u.topics, 'orphan-topic'},
  );
}
