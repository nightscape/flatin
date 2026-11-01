import 'dart:math';

import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';

import 'gen_settings.dart';

typedef SentenceLearner = ({
  int reached,
  Set<GrammarBundle> unlocked,
  List<PracticeItem> pool,
  bool Function(PracticeItem word, FormLabel label) practised,
});

/// A learner around the real [corpus]: the reached lesson of drawn settings;
/// every bundle of [items] unlocked, in a third of the draws thinned by a
/// tenth, then 0-3 bundles that corpus sentences use locked; the pool is
/// [items] without 0-2 items that corpus sentences use; every form practised
/// but, in two thirds of the draws, 1-6 forms that corpus tokens hold and 0-3
/// forms of construction heads and references.
SentenceLearner drawSentenceLearner(
  Random rng,
  SentenceCorpus corpus,
  List<PracticeItem> items,
) {
  final reached = reachedLesson(drawSettings(rng));
  final corpusItems = {
    for (final s in corpus.sentences)
      for (final t in s.tokens.whereType<FormToken>()) itemOfToken(items, t),
  };
  final corpusBundles = {
    for (final s in corpus.sentences)
      for (final t in s.tokens.whereType<FormToken>())
        bundleOf(itemOfToken(items, t), t.key),
  };
  final thin = rng.nextInt(3) == 0;
  final unlocked = {
    for (final w in items)
      for (final k in w.formOrder)
        if (!thin || rng.nextInt(10) > 0) bundleOf(w, k),
  }..removeAll((corpusBundles.toList()..shuffle(rng)).take(rng.nextInt(4)));
  final dropped = (corpusItems.toList()..shuffle(rng))
      .take(rng.nextInt(3))
      .toSet();
  final corpusForms = {
    for (final s in corpus.sentences)
      for (final t in s.tokens.whereType<FormToken>())
        (itemOfToken(items, t).id, t.key),
  };
  final markedForms = {
    for (final s in corpus.sentences)
      for (final i in [s.construction.head, ?s.construction.reference])
        if (s.tokens[i] case final FormToken t)
          (itemOfToken(items, t).id, t.key),
  };
  final off = rng.nextInt(3) == 0
      ? const <(String, String)>{}
      : {
          ...(corpusForms.toList()..shuffle(rng)).take(1 + rng.nextInt(6)),
          ...(markedForms.toList()..shuffle(rng)).take(rng.nextInt(4)),
        };
  return (
    reached: reached,
    unlocked: unlocked,
    pool: [
      for (final w in items)
        if (!dropped.contains(w)) w,
    ],
    practised: (w, l) => !off.contains((w.id, l.key)),
  );
}

/// The item of [items] whose lemma [t] names.
PracticeItem itemOfToken(List<PracticeItem> items, FormToken t) =>
    items.singleWhere((w) => w.lemma == t.lemma);

/// The sentences of [corpus] that [learner] can see, in corpus order: of a
/// lesson up to the reached one, of a kind in [constructions] when given,
/// every form token a form of a pool item in an unlocked bundle.
List<Sentence> visibleSentences(
  SentenceCorpus corpus,
  SentenceLearner learner, {
  Set<String>? constructions,
}) {
  bool placed(FormToken t) {
    final w = learner.pool.where((w) => w.lemma == t.lemma).firstOrNull;
    return w != null &&
        w.formOrder.contains(t.key) &&
        learner.unlocked.contains(bundleOf(w, t.key));
  }

  return [
    for (final s in corpus.sentences)
      if (s.lesson <= learner.reached &&
          (constructions?.contains(s.construction.kind.name) ?? true) &&
          s.tokens.whereType<FormToken>().every(placed))
        s,
  ];
}

/// The data a sentence context is built from.
typedef SentenceWorld = ({
  List<PracticeItem> items,
  Curriculum curriculum,
  LessonData lessons,
  SentenceCorpus corpus,
  GermanForms german,
});

/// A learner around the corpus: [settings], its filter and the context a
/// round hands a sentence kind for them (every file's practicable words, the
/// bundles the filter unlocks, the Kursstand).
typedef SettingsLearner = ({
  Settings settings,
  CourseFilter filter,
  ExerciseContext ctx,
});

/// The learner of [settings]; [german] replaces the world's German forms.
SettingsLearner settingsLearnerOf(
  SentenceWorld world,
  Settings settings, {
  GermanForms? german,
}) {
  final filter = CourseFilter(settings, world.curriculum, world.lessons);
  final pool = world.items.where(filter.reachesPractice).toList();
  return (
    settings: settings,
    filter: filter,
    ctx: ExerciseContext(
      unlocked: unlockedBundles(filter, pool),
      pool: pool,
      german: german ?? world.german,
      avoidMacronTwins: settings.avoidMacronTwins,
      formPracticed: (word, label) =>
          filter.formPracticed(word.dataFileId, label),
      sentences: world.corpus,
      reachedLesson: reachedLesson(settings),
    ),
  );
}

/// [drawSettings] whose word and form overrides come from the corpus' words
/// and forms, each off with chance [off]; the English UI (no German forms)
/// with chance [english].
SettingsLearner drawSettingsLearner(
  Random rng,
  SentenceWorld world, {
  double off = 0.1,
  double english = 0.2,
}) {
  final tokens = [
    for (final s in world.corpus.sentences) ...s.tokens.whereType<FormToken>(),
  ];
  final byLemma = {
    for (final t in tokens)
      t.lemma: world.items.singleWhere((w) => w.lemma == t.lemma),
  };
  final settings = drawSettings(
    rng,
    words: byLemma.keys.toSet(),
    forms: {
      for (final t in tokens)
        byLemma[t.lemma]!.dataFileId: {
          for (final u in tokens)
            if (byLemma[u.lemma]!.dataFileId == byLemma[t.lemma]!.dataFileId)
              u.key,
        },
    },
    off: off,
  );
  return settingsLearnerOf(
    world,
    settings,
    german: rng.nextDouble() < english ? const NoForms() : null,
  );
}
